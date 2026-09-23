import concurrent.futures
import hashlib
import hmac
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from backend.app import App, Problem, now, uid

class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.app=App(Path(tempfile.mkdtemp(prefix='vouchhunter-tests-'))/'test.sqlite3')
        self.owner=self.register('owner@example.test',company='Pizzeria Ett')
        self.other=self.register('other@example.test',company='Pizzeria Två')
        self.customer=self.register('customer@example.test')
        self.org=self.call('/api/me',token=self.owner)[1]['organizations'][0]['id']
        self.campaign=self.make_campaign()
    def call(self,path,body=None,token='',headers=None):
        raw=json.dumps(body).encode() if body is not None else b''
        environ={'PATH_INFO':path,'REQUEST_METHOD':'POST' if body is not None else 'GET','CONTENT_LENGTH':str(len(raw)),'CONTENT_TYPE':'application/json','wsgi.input':io.BytesIO(raw),'HTTP_HOST':'localhost:8080','REMOTE_ADDR':'127.0.0.1','HTTP_AUTHORIZATION':'Bearer '+token}
        environ.update(headers or {})
        result=[]
        response=b''.join(self.app(environ,lambda status,headers:result.append(status)))
        return int(result[0].split()[0]),json.loads(response)
    def register(self,email,company=''):
        status,result=self.call('/api/register',{'email':email,'password':'test-password-long','name':'Test User','company':company,'native':True})
        self.assertEqual(status,200,result);return result['token']
    def make_campaign(self,capacity=2,target=1):
        body={'org_id':self.org,'title':'En riktig jakt','description':'Hitta en pizza utomhus.','reward':'En gratis pizza','terms':'En pizza per person under perioden.','venue':'Pizzeria Ett, Stockholm','starts':now()-30,'ends':now()+3600,'target':target,'capacity':capacity,'voucher_days':14,'stops':[{'name':'Sergels torg','lat':59.3326,'lon':18.0649,'radius':40}]}
        status,c=self.call('/api/manage/campaigns',body,self.owner);self.assertEqual(status,200,c);return c
    def publish_for_test(self,c=None):
        c=c or self.campaign
        # Test fixture only: no production endpoint bypasses a payment.
        with self.app.store.transaction() as db:db.execute('UPDATE campaigns SET paid=1 WHERE id=?',(c['id'],))
        status,result=self.call('/api/manage/campaigns/'+c['id']+'/publish',{},self.owner)
        self.assertEqual(status,200,result)
    def collect(self,token=None,c=None,**override):
        c=c or self.campaign
        body={'stop_id':c['stops'][0]['id'],'lat':59.3326,'lon':18.0649,'accuracy':8,'captured_at':now()};body.update(override)
        return self.call('/api/hunts/'+c['id']+'/collect',body,token or self.customer)
    def start(self,token=None,c=None):return self.call('/api/hunts/'+(c or self.campaign)['id']+'/start',{},token or self.customer)
    def test_unpaid_cannot_publish(self):
        status,_=self.call('/api/manage/campaigns/'+self.campaign['id']+'/publish',{},self.owner)
        self.assertEqual(status,409)
        self.assertEqual(self.call('/api/campaigns')[1]['campaigns'],[])
    def test_cross_company_cannot_publish_or_list(self):
        status,_=self.call('/api/manage/campaigns/'+self.campaign['id']+'/publish',{},self.other)
        self.assertEqual(status,403)
        self.assertEqual(self.call('/api/manage/campaigns',token=self.other)[1]['campaigns'],[])
    def test_far_away_stale_and_inaccurate_locations_fail(self):
        self.publish_for_test();self.start()
        for changes in [{'lat':59.4},{'captured_at':now()-120},{'accuracy':60},{'lat':float('nan')},{'lon':float('inf')}]:
            with self.subTest(changes=changes):self.assertIn(self.collect(**changes)[0],(400,409))
    def test_duplicate_collection_issues_one_voucher(self):
        self.publish_for_test();self.start()
        first=self.collect();second=self.collect()
        self.assertEqual(first[0],200);self.assertEqual(first[1]['voucher']['id'],second[1]['voucher']['id'])
        with self.app.store.transaction() as db:self.assertEqual(db.execute('SELECT count(*) FROM vouchers').fetchone()[0],1)
    def test_redeem_once_and_cross_company_denied(self):
        self.publish_for_test();self.start();code=self.collect()[1]['voucher']['code']
        self.assertEqual(self.call('/api/vouchers/check',{'code':code},self.other)[0],403)
        self.assertEqual(self.call('/api/vouchers/check',{'code':code},self.owner)[0],200)
        def redeem():return self.call('/api/vouchers/redeem',{'code':code},self.owner)[0]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:redeem(),range(2)))
        self.assertEqual(sorted(results),[200,409])
    def test_capacity_under_simultaneous_starts(self):
        c=self.make_campaign(capacity=1);self.publish_for_test(c)
        customer2=self.register('another@example.test')
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda t:self.start(t,c)[0],[self.customer,customer2]))
        self.assertEqual(sorted(results),[200,409])
    def test_expired_reservation_cannot_collect_and_can_restart(self):
        self.publish_for_test();h=self.start()[1]
        with self.app.store.transaction() as db:db.execute('UPDATE hunts SET expires=? WHERE id=?',(now()-1,h['id']))
        self.assertEqual(self.collect()[0],409)
        self.assertEqual(self.start()[0],200);self.assertEqual(self.collect()[0],200)
    def test_paused_campaign_preserves_issued_voucher(self):
        self.publish_for_test();self.start();code=self.collect()[1]['voucher']['code']
        self.call('/api/manage/campaigns/'+self.campaign['id']+'/pause',{},self.owner)
        self.assertEqual(self.call('/api/vouchers/redeem',{'code':code},self.owner)[0],200)
    def test_logout_revokes_token(self):
        self.assertEqual(self.call('/api/logout',{},self.customer)[0],200)
        self.assertEqual(self.call('/api/me',token=self.customer)[0],401)
    def test_csrf_origin_rejected(self):
        status,_=self.call('/api/logout',{},self.customer,{'HTTP_ORIGIN':'https://evil.example'})
        self.assertEqual(status,403)
    def test_signed_payment_webhook_is_idempotent(self):
        with self.app.store.transaction() as db:
            db.execute('INSERT INTO payment_orders VALUES(?,?,?,?,?,?,0)',('cs_test',self.campaign['id'],10000,'sek','https://checkout.stripe.com/test',now()+3600))
        event={'id':'evt_123','type':'checkout.session.completed','data':{'object':{'id':'cs_test','mode':'payment','amount_total':10000,'currency':'sek','payment_status':'paid','metadata':{'campaign_id':self.campaign['id']}}}}
        stamp=str(now());raw=json.dumps(event).encode();signature=hmac.new(b'test-secret',stamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
        with patch.dict(os.environ,{'STRIPE_WEBHOOK_SECRET':'test-secret'}):
            self.assertEqual(self.call('/api/payments/webhook',event,headers={'HTTP_STRIPE_SIGNATURE':f't={stamp},v1=wrong'})[0],400)
            for _ in range(2):self.assertEqual(self.call('/api/payments/webhook',event,headers={'HTTP_STRIPE_SIGNATURE':f't={stamp},v1={signature}'})[0],200)
        with self.app.store.transaction() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM webhook_events').fetchone()[0],1)
            self.assertEqual(db.execute('SELECT paid FROM campaigns WHERE id=?',(self.campaign['id'],)).fetchone()[0],1)
    def test_path_traversal_cannot_serve_source(self):
        output=[];body=b''.join(self.app({'PATH_INFO':'/../backend/app.py','REQUEST_METHOD':'GET'},lambda status,headers:output.append(status)))
        self.assertTrue(output[0].startswith('404'))

if __name__=='__main__': unittest.main()
