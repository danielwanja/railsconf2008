CREATE TABLE schema_info (version integer);
CREATE TABLE tasks ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "title" varchar(255) DEFAULT NULL, "description" text DEFAULT NULL, "due" datetime DEFAULT NULL, "completed" boolean DEFAULT NULL, "created_at" datetime DEFAULT NULL, "updated_at" datetime DEFAULT NULL);
INSERT INTO schema_info (version) VALUES (1)