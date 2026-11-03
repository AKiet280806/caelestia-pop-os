#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
exec /usr/bin/python3 "$(dirname -- "${BASH_SOURCE[0]}")/installer/install.py" "$@"
