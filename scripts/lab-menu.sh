#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "Makefile" ]]; then
  echo "Run this script from the project root (where Makefile exists)."
  exit 1
fi

run_follow_command() {
  local label="$1"
  shift

  echo
  echo "--- ${label} ---"
  echo "Press Enter to stop and return to menu."

  "$@" &
  local cmd_pid=$!

  read -r

  if kill -0 "$cmd_pid" 2>/dev/null; then
    kill "$cmd_pid" 2>/dev/null || true
    wait "$cmd_pid" 2>/dev/null || true
  fi

  echo "Returned to menu."
}

show_menu() {
  cat <<'MENU'

Fintech Automation Lab Menu
1) Start stack
2) Status (docker compose ps)
3) Logs n8n (Enter to return)
4) Logs postgres (Enter to return)
5) Logs metabase (Enter to return)
6) Stripe listen test webhook (Enter to stop)
7) Stripe listen active webhook (Enter to stop)
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
    3) run_follow_command "n8n logs" docker compose logs -f n8n ;;
    4) run_follow_command "Postgres logs" docker compose logs -f postgres ;;
    5) run_follow_command "Metabase logs" docker compose logs -f metabase ;;
    6) run_follow_command "Stripe listen -> webhook-test" stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook-test/stripe-checkout ;;
    7) run_follow_command "Stripe listen -> webhook" stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook/stripe-checkout ;;
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
