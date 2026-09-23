CREATE TABLE platform_admins(user_id TEXT PRIMARY KEY REFERENCES users(id));
CREATE TABLE briefs(id TEXT PRIMARY KEY,org_id TEXT NOT NULL REFERENCES organizations(id),title TEXT NOT NULL,description TEXT NOT NULL,reward TEXT NOT NULL,area TEXT NOT NULL,preferred_start TEXT NOT NULL,created INTEGER NOT NULL,campaign_id TEXT REFERENCES campaigns(id));
CREATE TABLE assets(id TEXT PRIMARY KEY,name TEXT NOT NULL,format TEXT NOT NULL CHECK(format IN ('glb','usdz')),filename TEXT NOT NULL UNIQUE,size INTEGER NOT NULL,sha256 TEXT NOT NULL,created INTEGER NOT NULL);
CREATE TABLE models(id TEXT PRIMARY KEY,name TEXT NOT NULL,glb_asset_id TEXT NOT NULL REFERENCES assets(id),usdz_asset_id TEXT NOT NULL REFERENCES assets(id),created INTEGER NOT NULL);
ALTER TABLE campaigns ADD COLUMN model_id TEXT REFERENCES models(id);
