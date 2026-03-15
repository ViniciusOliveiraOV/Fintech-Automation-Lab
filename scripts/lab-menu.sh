#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "Makefile" ]]; then
  echo "Run this script from the project root (where Makefile exists)."
  exit 1
fi

show_menu() {
  cat <<'MENU'

Fintech Automation Lab Menu
1) Start stack
2) Status (docker compose ps)
3) Logs n8n
4) Logs postgres
5) Logs metabase
6) Stripe listen (test webhook)
7) Stripe listen (active webhook)
8) Stripe trigger checkout.session.completed
9) Curl test webhook payload
10) Curl active webhook payload
11) Threshold test (>500)
12) DB list tables
13) DB show last payments
14) DB show total revenue
15) Reset payments table
16) Full reset (down -v + up -d)
0) Exit
MENU
}

while true; do
  show_menu
  read -r -p "Choose an option: " option

  case "$option" in
    1) make up ;;
    2) make ps ;;
    3) make logs-n8n ;;
    4) make logs-postgres ;;
    5) make logs-metabase ;;
    6) make listen-test ;;
    7) make listen-active ;;
    8) make trigger ;;
    9) make curl-test ;;
    10) make curl-active ;;
    11) make threshold-test ;;
    12) make db-tables ;;
    13) make db-last ;;
    14) make db-revenue ;;
    15) make reset-payments ;;
    16) make reset-all ;;
    0)
      echo "Bye."
      exit 0
      ;;
    *)
      echo "Invalid option."
      ;;
  esac

done
