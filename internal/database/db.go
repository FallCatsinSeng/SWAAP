// Package database provides PostgreSQL connection and schema migration.
package database

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"time"

	_ "github.com/lib/pq" // PostgreSQL driver
)

// DB wraps a *sql.DB with application helpers.
type DB struct {
	*sql.DB
	logger *slog.Logger
}

// Config holds database connection parameters.
type Config struct {
	Host     string
	Port     string
	User     string
	Password string
	Name     string
	SSLMode  string
}

// DSN returns the PostgreSQL connection string.
func (c Config) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.Name, c.SSLMode,
	)
}

// Open connects to PostgreSQL and runs migrations.
func Open(cfg Config, logger *slog.Logger) (*DB, error) {
	conn, err := sql.Open("postgres", cfg.DSN())
	if err != nil {
		return nil, fmt.Errorf("database open: %w", err)
	}

	// Connection pool settings
	conn.SetMaxOpenConns(25)
	conn.SetMaxIdleConns(5)
	conn.SetConnMaxLifetime(5 * time.Minute)

	// Verify connection
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := conn.PingContext(ctx); err != nil {
		conn.Close()
		return nil, fmt.Errorf("database ping: %w", err)
	}

	db := &DB{DB: conn, logger: logger}

	// Run migrations
	if err := db.migrate(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("database migrate: %w", err)
	}

	logger.Info("database connected and migrated", "host", cfg.Host, "dbname", cfg.Name)
	return db, nil
}

// migrate runs all schema migrations in order.
func (db *DB) migrate() error {
	for i, m := range migrations {
		if _, err := db.Exec(m); err != nil {
			return fmt.Errorf("migration %d: %w", i, err)
		}
	}
	return nil
}

// migrations is the ordered list of SQL statements to run on startup.
var migrations = []string{
	// Tabel aspirasi/aduan
	`CREATE TABLE IF NOT EXISTS aspirasi (
		id          SERIAL PRIMARY KEY,
		nim         TEXT    NOT NULL,
		nama        TEXT    NOT NULL,
		semester    TEXT    DEFAULT '',
		jurusan     TEXT    DEFAULT '',
		sasaran     TEXT    NOT NULL,
		kritik      TEXT    NOT NULL,
		saran       TEXT    NOT NULL,
		is_anonim   BOOLEAN DEFAULT FALSE,
		status      TEXT    DEFAULT 'pending',
		admin_reply TEXT    DEFAULT '',
		created_at  TIMESTAMPTZ DEFAULT NOW(),
		updated_at  TIMESTAMPTZ DEFAULT NOW()
	)`,

	// Add admin_reply to existing tables if needed (safe to run multiple times)
	`ALTER TABLE aspirasi ADD COLUMN IF NOT EXISTS admin_reply TEXT DEFAULT ''`,

	// Tabel admin
	`CREATE TABLE IF NOT EXISTS admin (
		nim        TEXT PRIMARY KEY,
		nama       TEXT    NOT NULL DEFAULT '',
		created_at TIMESTAMPTZ DEFAULT NOW()
	)`,

	// Seed default admin: STI202303534
	`INSERT INTO admin (nim, nama) VALUES ('STI202303534', 'Admin')
	 ON CONFLICT (nim) DO NOTHING`,

	// Index for faster queries
	`CREATE INDEX IF NOT EXISTS idx_aspirasi_created ON aspirasi (created_at DESC)`,
	`CREATE INDEX IF NOT EXISTS idx_aspirasi_nim ON aspirasi (nim)`,
	`CREATE INDEX IF NOT EXISTS idx_aspirasi_status ON aspirasi (status)`,
}
