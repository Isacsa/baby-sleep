#!/bin/bash
# Aplica migrations Supabase do monorepo
#
# Uso: ./scripts/apply-migrations.sh
#
# Este script navega para backend/supabase e executa supabase db push.
# Requer Supabase CLI instalado e projeto linkado (supabase link).

set -e

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR/../backend/supabase"

echo "📁 Working directory: $(pwd)"
echo "🚀 Applying migrations..."

supabase db push

echo "✅ Migrations applied successfully!"
