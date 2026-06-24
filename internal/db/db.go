// Package db gerencia a conexão com o Postgres (schema analytics).
package db

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// DB encapsula o pool de conexões.
type DB struct {
	Pool *pgxpool.Pool
}

// New abre um pool a partir da URL de conexão e valida com um ping.
func New(ctx context.Context, url string) (*DB, error) {
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("could not create connection pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("could not reach database: %w", err)
	}
	return &DB{Pool: pool}, nil
}

// Close encerra o pool.
func (d *DB) Close() { d.Pool.Close() }
