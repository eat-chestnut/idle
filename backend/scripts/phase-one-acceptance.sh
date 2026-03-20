#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${BACKEND_DIR}"

echo "[phase-one] diagnose"
php artisan phase-one:diagnose

echo "[phase-one] targeted acceptance tests"
php artisan test \
  tests/Feature/Api/PhaseOneAuthenticationApiTest.php \
  tests/Feature/Api/PhaseOneCharacterEquipmentApiTest.php \
  tests/Feature/Api/PhaseOneBattlePrepareApiTest.php \
  tests/Feature/Api/PhaseOneBattleSettlementApiTest.php \
  tests/Feature/Api/PhaseOneFrontendContractArtifactTest.php \
  tests/Feature/Api/PhaseOnePlayerJourneySmokeTest.php \
  tests/Feature/Admin/PhaseOneAdminPagesTest.php \
  tests/Feature/Console/PhaseOneEnvironmentDiagnoseCommandTest.php \
  tests/Feature/Console/WorkflowLockCheckCommandTest.php \
  tests/Unit/Support/WorkflowLockServiceTest.php
