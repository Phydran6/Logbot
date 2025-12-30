#!/bin/bash
#===============================================================================
# LogBot Patch v1.1.0 - Incoming Webhooks für n8n Integration
#===============================================================================
# Autor:        PF
# Version:      2024-12-30
# Claude Model: Claude Opus 4 (claude-sonnet-4-20250514)
#
# Beschreibung:
#   Dieses Patch erweitert LogBot um Incoming Webhooks die von externen
#   Tools wie n8n, Make oder Zapier abgefragt werden koennen.
#
# Aenderungen:
#   - Neue Webhook-API mit Token-Authentifizierung
#   - Oeffentlicher Endpoint /api/webhook/{id}/call
#   - Filter: Severity, Hostname, Source
#   - Einfach/Experten-Modus im UI
#   - Aufruf-Statistiken (count, last_called)
#
# Voraussetzungen:
#   - LogBot v1.0.0 bereits installiert
#   - Docker laeuft
#
# Usage: sudo bash logbot-patch-v1.1.0.sh
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/logbot"
BACKUP_DIR="/opt/logbot/backups/$(date +%Y%m%d_%H%M%S)"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_root() {
    [[ $EUID -ne 0 ]] && log_error "Dieses Skript muss als root ausgefuehrt werden (sudo)"
}

check_logbot() {
    [[ ! -d "$INSTALL_DIR" ]] && log_error "LogBot nicht gefunden in $INSTALL_DIR"
    [[ ! -f "$INSTALL_DIR/docker-compose.yml" ]] && log_error "docker-compose.yml nicht gefunden"
    log_ok "LogBot Installation gefunden"
}

create_backup() {
    log_info "Erstelle Backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp "$INSTALL_DIR/backend/app/routes/webhooks.py" "$BACKUP_DIR/webhooks.py.bak" 2>/dev/null || true
    cp "$INSTALL_DIR/frontend/src/views/Webhooks.vue" "$BACKUP_DIR/Webhooks.vue.bak" 2>/dev/null || true
    cp "$INSTALL_DIR/backend/app/main.py" "$BACKUP_DIR/main.py.bak"
    log_ok "Backup erstellt"
}

patch_webhooks_backend() {
    log_info "Patche Backend webhooks.py..."
    
    cat > "$INSTALL_DIR/backend/app/routes/webhooks.py" << 'WEBHOOKS_PY_EOF'
"""
LogBot - Incoming Webhooks API v1.1.0
=====================================
Erstellt Webhook-Endpoints die von externen Tools (n8n, Make, Zapier) aufgerufen werden koennen.
Token-basierte Authentifizierung fuer sichere Abfragen.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta, timezone
import secrets
import hashlib
import json

from app.config.database import get_db
from app.routes.auth import get_current_user
from app.models.user import User

router = APIRouter()


class WebhookCreate(BaseModel):
    name: str
    description: Optional[str] = None
    filter_severities: List[str] = ["emergency", "alert", "critical", "error", "warning", "notice", "info", "debug"]
    filter_hostname: Optional[str] = None
    filter_source: Optional[str] = None
    max_results: int = 100
    include_raw: bool = False


class WebhookUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    filter_severities: Optional[List[str]] = None
    filter_hostname: Optional[str] = None
    filter_source: Optional[str] = None
    max_results: Optional[int] = None
    include_raw: Optional[bool] = None
    is_active: Optional[bool] = None


class WebhookOut(BaseModel):
    id: str
    name: str
    description: Optional[str]
    token: str
    webhook_url: str
    filter_severities: List[str]
    filter_hostname: Optional[str]
    filter_source: Optional[str]
    max_results: int
    include_raw: bool
    is_active: bool
    created_at: datetime
    last_called: Optional[datetime] = None
    call_count: int = 0


def generate_token() -> str:
    """Generiert einen sicheren URL-safe Token."""
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    """Hasht den Token mit SHA256 fuer sichere Speicherung."""
    return hashlib.sha256(token.encode()).hexdigest()


def build_webhook_url(request_base: str, webhook_id: str, token: str) -> str:
    """Baut die vollstaendige Webhook-URL."""
    return f"{request_base}/api/webhook/{webhook_id}/call?token={token}"


@router.get("", response_model=List[WebhookOut])
async def list_webhooks(
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """Listet alle Webhooks auf."""
    result = await db.execute(text("""
        SELECT id, name, headers->>'description' as description,
               '********' as token,
               headers->>'filter_severities' as filter_severities,
               headers->>'filter_hostname' as filter_hostname,
               headers->>'filter_source' as filter_source,
               COALESCE((headers->>'max_results')::int, 100) as max_results,
               COALESCE((headers->>'include_raw')::boolean, false) as include_raw,
               is_active, created_at,
               (headers->>'last_called')::timestamptz as last_called,
               COALESCE((headers->>'call_count')::int, 0) as call_count
        FROM webhooks ORDER BY created_at DESC
    """))
    
    base_url = str(request.base_url).rstrip('/')
    webhooks = []
    
    for r in result.fetchall():
        sevs = r[4]
        if isinstance(sevs, str):
            try:
                sevs = json.loads(sevs)
            except:
                sevs = ["error"]
        
        webhooks.append(WebhookOut(
            id=str(r[0]),
            name=r[1],
            description=r[2],
            token="********",
            webhook_url=f"{base_url}/api/webhook/{r[0]}/call?token=YOUR_TOKEN",
            filter_severities=sevs or ["error"],
            filter_hostname=r[5],
            filter_source=r[6],
            max_results=r[7] or 100,
            include_raw=r[8] or False,
            is_active=r[9],
            created_at=r[10],
            last_called=r[11],
            call_count=r[12] or 0
        ))
    
    return webhooks


@router.post("", response_model=WebhookOut)
async def create_webhook(
    data: WebhookCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """Erstellt einen neuen Webhook mit Token."""
    token = generate_token()
    token_hash = hash_token(token)
    
    config = {
        "description": data.description,
        "filter_severities": json.dumps(data.filter_severities),
        "filter_hostname": data.filter_hostname,
        "filter_source": data.filter_source,
        "max_results": data.max_results,
        "include_raw": data.include_raw,
        "call_count": 0
    }
    
    result = await db.execute(
        text("""
            INSERT INTO webhooks (name, url, method, headers, is_active) 
            VALUES (:name, :token_hash, 'GET', :config, true) 
            RETURNING id, created_at
        """),
        {"name": data.name, "token_hash": token_hash, "config": json.dumps(config)}
    )
    row = result.fetchone()
    await db.commit()
    
    webhook_id = str(row[0])
    base_url = str(request.base_url).rstrip('/')
    
    return WebhookOut(
        id=webhook_id,
        name=data.name,
        description=data.description,
        token=token,  # Token nur hier sichtbar!
        webhook_url=build_webhook_url(base_url, webhook_id, token),
        filter_severities=data.filter_severities,
        filter_hostname=data.filter_hostname,
        filter_source=data.filter_source,
        max_results=data.max_results,
        include_raw=data.include_raw,
        is_active=True,
        created_at=row[1],
        call_count=0
    )


@router.get("/{webhook_id}", response_model=WebhookOut)
async def get_webhook(
    webhook_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """Holt Details eines Webhooks."""
    result = await db.execute(
        text("SELECT id, name, headers, is_active, created_at FROM webhooks WHERE id = :id"),
        {"id": webhook_id}
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "Webhook not found")
    
    config = row[2] or {}
    sevs = config.get('filter_severities', '["error"]')
    if isinstance(sevs, str):
        try:
            sevs = json.loads(sevs)
        except:
            sevs = ["error"]
    
    base_url = str(request.base_url).rstrip('/')
    
    return WebhookOut(
        id=str(row[0]),
        name=row[1],
        description=config.get('description'),
        token="********",
        webhook_url=f"{base_url}/api/webhook/{row[0]}/call?token=YOUR_TOKEN",
        filter_severities=sevs,
        filter_hostname=config.get('filter_hostname'),
        filter_source=config.get('filter_source'),
        max_results=config.get('max_results', 100),
        include_raw=config.get('include_raw', False),
        is_active=row[3],
        created_at=row[4],
        last_called=config.get('last_called'),
        call_count=config.get('call_count', 0)
    )


@router.put("/{webhook_id}", response_model=WebhookOut)
async def update_webhook(
    webhook_id: str,
    data: WebhookUpdate,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """Aktualisiert einen Webhook."""
    result = await db.execute(
        text("SELECT name, headers, is_active FROM webhooks WHERE id = :id"),
        {"id": webhook_id}
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "Webhook not found")
    
    current_config = row[1] or {}
    new_name = data.name if data.name is not None else row[0]
    
    if data.description is not None:
        current_config['description'] = data.description
    if data.filter_severities is not None:
        current_config['filter_severities'] = json.dumps(data.filter_severities)
    if data.filter_hostname is not None:
        current_config['filter_hostname'] = data.filter_hostname
    if data.filter_source is not None:
        current_config['filter_source'] = data.filter_source
    if data.max_results is not None:
        current_config['max_results'] = data.max_results
    if data.include_raw is not None:
        current_config['include_raw'] = data.include_raw
    
    new_active = data.is_active if data.is_active is not None else row[2]
    
    await db.execute(
        text("UPDATE webhooks SET name = :name, headers = :config, is_active = :active WHERE id = :id"),
        {"id": webhook_id, "name": new_name, "config": json.dumps(current_config), "active": new_active}
    )
    await db.commit()
    
    return await get_webhook(webhook_id, request, db, user)


@router.post("/{webhook_id}/regenerate-token")
async def regenerate_token(
    webhook_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """Generiert einen neuen Token (invalidiert den alten)."""
    result = await db.execute(
        text("SELECT id FROM webhooks WHERE id = :id"),
        {"id": webhook_id}
    )
    if not result.fetchone():
        raise HTTPException(404, "Webhook not found")
    
    token = generate_token()
    token_hash = hash_token(token)
    
    await db.execute(
        text("UPDATE webhooks SET url = :token_hash WHERE id = :id"),
        {"id": webhook_id, "token_hash": token_hash}
    )
    await db.commit()
    
    base_url = str(request.base_url).rstrip('/')
    
    return {
        "token": token,
        "webhook_url": build_webhook_url(base_url, webhook_id, token),
        "message": "Token regeneriert! Alter Token ist ungueltig."
    }


@router.delete("/{webhook_id}")
async def delete_webhook(
    webhook_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """Loescht einen Webhook."""
    result = await db.execute(
        text("DELETE FROM webhooks WHERE id = :id RETURNING id"),
        {"id": webhook_id}
    )
    if not result.fetchone():
        raise HTTPException(404, "Webhook not found")
    await db.commit()
    return {"status": "deleted"}


@router.get("/{webhook_id}/example")
async def get_example_response(
    webhook_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user)
):
    """Zeigt ein Beispiel der Webhook-Response."""
    result = await db.execute(
        text("SELECT name, headers FROM webhooks WHERE id = :id"),
        {"id": webhook_id}
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(404, "Webhook not found")
    
    config = row[1] or {}
    sevs = config.get('filter_severities', '["error"]')
    if isinstance(sevs, str):
        try:
            sevs = json.loads(sevs)
        except:
            sevs = ["error"]
    
    return {
        "description": "So sieht die Response aus wenn n8n den Webhook aufruft:",
        "example_response": {
            "webhook": row[0],
            "query": {
                "since_minutes": 60,
                "severities": sevs,
                "hostname_filter": config.get('filter_hostname'),
                "source_filter": config.get('filter_source')
            },
            "count": 2,
            "logs": [
                {
                    "id": 12345,
                    "hostname": "webserver-01",
                    "timestamp": "2025-01-15T14:32:18.123Z",
                    "level": "error",
                    "source": "nginx",
                    "message": "connect() failed (111: Connection refused)"
                },
                {
                    "id": 12340,
                    "hostname": "api-server",
                    "timestamp": "2025-01-15T14:28:00.789Z",
                    "level": "critical",
                    "source": "app",
                    "message": "Database connection lost"
                }
            ]
        },
        "n8n_zugriff": {
            "alle_logs": "$json.logs",
            "erste_message": "$json.logs[0].message",
            "anzahl": "$json.count"
        }
    }


# =============================================================================
# OEFFENTLICHER ENDPOINT - Kein Bearer Token noetig, nur Webhook-Token
# =============================================================================

async def call_webhook(
    webhook_id: str,
    token: str = Query(..., description="Webhook Token"),
    since_minutes: int = Query(60, description="Logs der letzten X Minuten"),
    db: AsyncSession = Depends(get_db)
):
    """
    Oeffentlicher Endpoint fuer externe Tools (n8n, Make, Zapier).
    Authentifizierung erfolgt ueber den Token-Parameter.
    """
    token_hash = hash_token(token)
    
    # Webhook laden und Token pruefen
    result = await db.execute(
        text("SELECT id, name, headers, is_active, url FROM webhooks WHERE id = :id"),
        {"id": webhook_id}
    )
    row = result.fetchone()
    
    if not row:
        raise HTTPException(404, "Webhook not found")
    
    if row[4] != token_hash:
        raise HTTPException(401, "Invalid token")
    
    if not row[3]:
        raise HTTPException(403, "Webhook is disabled")
    
    config = row[2] or {}
    webhook_name = row[1]
    
    # Filter aus Config laden
    sevs = config.get('filter_severities', '["error"]')
    if isinstance(sevs, str):
        try:
            sevs = json.loads(sevs)
        except:
            sevs = ["error"]
    
    filter_hostname = config.get('filter_hostname')
    filter_source = config.get('filter_source')
    max_results = config.get('max_results', 100)
    include_raw = config.get('include_raw', False)
    
    # Query bauen
    where_clauses = ["timestamp > :since"]
    params = {
        "since": datetime.now(timezone.utc) - timedelta(minutes=since_minutes),
        "limit": min(max_results, 1000)
    }
    
    if sevs:
        where_clauses.append("level = ANY(:severities)")
        params["severities"] = sevs
    
    if filter_hostname:
        where_clauses.append("hostname ~* :hostname")
        params["hostname"] = filter_hostname
    
    if filter_source:
        where_clauses.append("source = :source")
        params["source"] = filter_source
    
    where_sql = " AND ".join(where_clauses)
    
    columns = "id, hostname, timestamp, level, source, message"
    if include_raw:
        columns += ", raw_message"
    
    # Logs abfragen
    result = await db.execute(
        text(f"SELECT {columns} FROM logs WHERE {where_sql} ORDER BY timestamp DESC LIMIT :limit"),
        params
    )
    
    logs = []
    for r in result.fetchall():
        log_entry = {
            "id": r[0],
            "hostname": r[1],
            "timestamp": r[2].isoformat() if r[2] else None,
            "level": r[3],
            "source": r[4],
            "message": r[5]
        }
        if include_raw and len(r) > 6:
            log_entry["raw"] = r[6]
        logs.append(log_entry)
    
    # Statistiken updaten
    call_count = config.get('call_count', 0) + 1
    config['call_count'] = call_count
    config['last_called'] = datetime.now(timezone.utc).isoformat()
    
    await db.execute(
        text("UPDATE webhooks SET headers = :config WHERE id = :id"),
        {"id": webhook_id, "config": json.dumps(config)}
    )
    await db.commit()
    
    return {
        "webhook": webhook_name,
        "query": {
            "since_minutes": since_minutes,
            "severities": sevs,
            "hostname_filter": filter_hostname,
            "source_filter": filter_source
        },
        "count": len(logs),
        "logs": logs
    }
WEBHOOKS_PY_EOF

    log_ok "Backend webhooks.py gepatcht"
}

patch_main_py() {
    log_info "Patche Backend main.py..."
    
    # Pruefen ob der Patch bereits angewendet wurde
    if grep -q "call_webhook" "$INSTALL_DIR/backend/app/main.py"; then
        log_warn "main.py bereits gepatcht - ueberspringe"
        return 0
    fi
    
    # Patch am Ende anfuegen
    cat >> "$INSTALL_DIR/backend/app/main.py" << 'MAIN_PY_PATCH_EOF'

# =============================================================================
# PATCH v1.1.0: Oeffentlicher Webhook Endpoint
# =============================================================================
from app.routes.webhooks import call_webhook
app.add_api_route("/api/webhook/{webhook_id}/call", call_webhook, methods=["GET"], tags=["webhook-public"])
MAIN_PY_PATCH_EOF

    log_ok "Backend main.py gepatcht"
}

patch_webhooks_frontend() {
    log_info "Patche Frontend Webhooks.vue..."
    
    cat > "$INSTALL_DIR/frontend/src/views/Webhooks.vue" << 'WEBHOOKS_VUE_EOF'
<template>
  <div class="p-6">
    <div class="flex justify-between mb-6">
      <div>
        <h2 class="text-2xl font-bold">Webhooks</h2>
        <p class="text-slate-400 text-sm mt-1">Erstelle Endpoints die n8n aufrufen kann</p>
      </div>
      <button @click="openCreate" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded">
        + Neuer Webhook
      </button>
    </div>

    <div class="bg-gradient-to-r from-blue-900/50 to-purple-900/50 border border-blue-500/50 rounded-lg p-4 mb-6">
      <h3 class="text-blue-400 font-semibold mb-2">So funktioniert's</h3>
      <div class="text-sm text-slate-300 space-y-1">
        <p>1. Webhook erstellen und URL kopieren</p>
        <p>2. In n8n: HTTP Request Node mit GET und der URL</p>
        <p>3. Fertig - n8n bekommt die Logs als JSON</p>
      </div>
    </div>

    <div class="space-y-4">
      <div v-for="wh in webhooks" :key="wh.id" class="bg-slate-800 rounded-lg border border-slate-700 p-4">
        <div class="flex justify-between items-start">
          <div class="flex-1">
            <div class="flex items-center gap-3 mb-2">
              <span class="w-3 h-3 rounded-full" :class="wh.is_active ? 'bg-green-500' : 'bg-slate-500'"></span>
              <span class="font-semibold text-lg">{{ wh.name }}</span>
            </div>
            <p v-if="wh.description" class="text-sm text-slate-400 mb-2">{{ wh.description }}</p>
            <div class="flex gap-4 text-xs text-slate-500">
              <span>{{ wh.call_count || 0 }} Aufrufe</span>
              <span v-if="wh.last_called">Zuletzt: {{ formatDate(wh.last_called) }}</span>
            </div>
          </div>
          <div class="flex gap-2">
            <button @click="showDetails(wh)" class="px-3 py-1.5 bg-purple-600 hover:bg-purple-700 rounded text-sm">URL anzeigen</button>
            <button @click="openEdit(wh)" class="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 rounded text-sm">Bearbeiten</button>
            <button @click="deleteWebhook(wh.id)" class="px-3 py-1.5 bg-red-600 hover:bg-red-700 rounded text-sm">Loeschen</button>
          </div>
        </div>
      </div>

      <div v-if="webhooks.length === 0" class="bg-slate-800 p-12 rounded-lg text-center">
        <p class="text-5xl mb-4">🔗</p>
        <p class="text-xl mb-2">Keine Webhooks vorhanden</p>
        <button @click="openCreate" class="mt-4 px-6 py-2 bg-blue-600 rounded">+ Ersten Webhook erstellen</button>
      </div>
    </div>

    <!-- Create/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
      <div class="bg-slate-800 rounded-lg w-full max-w-xl">
        <div class="p-6 border-b border-slate-700 flex justify-between items-center">
          <h3 class="text-xl font-bold">{{ isEdit ? 'Webhook bearbeiten' : 'Neuer Webhook' }}</h3>
          <button @click="closeModal" class="text-slate-400 hover:text-white text-2xl">&times;</button>
        </div>
        
        <form @submit.prevent="saveWebhook" class="p-6 space-y-5">
          <div>
            <label class="block text-sm text-slate-400 mb-1">Name *</label>
            <input v-model="form.name" placeholder="z.B. n8n-Logs" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" required />
          </div>

          <div>
            <label class="block text-sm text-slate-400 mb-1">Beschreibung (optional)</label>
            <input v-model="form.description" placeholder="Wofuer ist dieser Webhook?" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" />
          </div>

          <div class="flex items-center gap-3 pt-2 border-t border-slate-700">
            <button type="button" @click="expertMode = !expertMode" class="flex items-center gap-2 text-sm" :class="expertMode ? 'text-blue-400' : 'text-slate-500'">
              <span class="w-10 h-5 rounded-full relative" :class="expertMode ? 'bg-blue-600' : 'bg-slate-600'">
                <span class="absolute top-0.5 w-4 h-4 bg-white rounded-full transition-all" :class="expertMode ? 'left-5' : 'left-0.5'"></span>
              </span>
              Experten-Modus
            </button>
          </div>

          <div v-if="expertMode" class="space-y-4 pt-4 border-t border-slate-700">
            <div>
              <label class="block text-sm text-slate-400 mb-2">Nur diese Log-Level</label>
              <div class="flex flex-wrap gap-2">
                <label v-for="sev in allSeverities" :key="sev" class="flex items-center px-3 py-1.5 rounded cursor-pointer text-sm" :class="form.filter_severities.includes(sev) ? severityClass(sev) : 'bg-slate-700 text-slate-400'">
                  <input type="checkbox" :value="sev" v-model="form.filter_severities" class="hidden" />{{ sev }}
                </label>
              </div>
            </div>

            <div>
              <label class="block text-sm text-slate-400 mb-1">Nur von diesem Host (leer = alle)</label>
              <input v-model="form.filter_hostname" placeholder="z.B. webserver-01" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" />
            </div>

            <div>
              <label class="block text-sm text-slate-400 mb-1">Nur diese Quelle</label>
              <select v-model="form.filter_source" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded">
                <option value="">Alle Quellen</option>
                <option value="linux">Linux</option>
                <option value="auth">Auth (SSH, sudo)</option>
                <option value="unifi">UniFi</option>
                <option value="syslog">Syslog</option>
              </select>
            </div>

            <div>
              <label class="block text-sm text-slate-400 mb-1">Max. Logs pro Abfrage</label>
              <input v-model.number="form.max_results" type="number" min="1" max="1000" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" />
            </div>
          </div>

          <div v-if="error" class="text-red-400 text-sm p-3 bg-red-900/30 rounded">{{ error }}</div>

          <div class="flex gap-3 pt-4">
            <button type="button" @click="closeModal" class="flex-1 py-2 bg-slate-700 hover:bg-slate-600 rounded">Abbrechen</button>
            <button type="submit" class="flex-1 py-2 bg-blue-600 hover:bg-blue-700 rounded">{{ isEdit ? 'Speichern' : 'Erstellen' }}</button>
          </div>
        </form>
      </div>
    </div>

    <!-- Token Modal -->
    <div v-if="showTokenModal" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
      <div class="bg-slate-800 rounded-lg w-full max-w-2xl">
        <div class="p-6 border-b border-slate-700 bg-green-900/30">
          <h3 class="text-xl font-bold text-green-400">Webhook erstellt!</h3>
        </div>
        <div class="p-6 space-y-4">
          <div class="bg-red-900/30 border border-red-500 rounded p-4">
            <p class="text-red-400 font-semibold">Wichtig: Token nur jetzt sichtbar!</p>
            <p class="text-sm text-red-300">Kopiere die URL jetzt und speichere sie.</p>
          </div>

          <div>
            <label class="block text-sm text-slate-400 mb-2">Deine Webhook URL:</label>
            <div class="flex gap-2">
              <input :value="createdWebhook?.webhook_url" readonly class="flex-1 px-4 py-2 bg-slate-900 border border-slate-600 rounded font-mono text-sm text-green-400" />
              <button @click="copyUrl" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded">Kopieren</button>
            </div>
          </div>

          <div class="bg-slate-900 rounded-lg p-4">
            <h4 class="font-semibold mb-3 text-blue-400">In n8n einfuegen:</h4>
            <ol class="text-sm space-y-2 text-slate-300">
              <li>1. Neuen HTTP Request Node erstellen</li>
              <li>2. Method: GET</li>
              <li>3. URL: Die kopierte URL einfuegen</li>
              <li>4. Fertig!</li>
            </ol>
          </div>

          <button @click="showTokenModal = false; fetchWebhooks()" class="w-full py-2 bg-slate-700 hover:bg-slate-600 rounded">Schliessen</button>
        </div>
      </div>
    </div>

    <!-- URL Details Modal -->
    <div v-if="showDetailsModal" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
      <div class="bg-slate-800 rounded-lg w-full max-w-2xl">
        <div class="p-6 border-b border-slate-700 flex justify-between items-center">
          <h3 class="text-xl font-bold">{{ selectedWebhook?.name }}</h3>
          <button @click="showDetailsModal = false" class="text-slate-400 hover:text-white text-2xl">&times;</button>
        </div>
        <div class="p-6 space-y-6">
          <div>
            <label class="text-sm text-slate-400 mb-2 block">Webhook URL:</label>
            <div class="bg-slate-900 p-3 rounded font-mono text-sm break-all text-green-400">
              {{ getWebhookUrl(selectedWebhook) }}
            </div>
            <p class="text-xs text-slate-500 mt-2">Ersetze YOUR_TOKEN mit deinem gespeicherten Token</p>
          </div>

          <div class="flex gap-2">
            <button @click="regenerateToken" class="flex-1 py-2 bg-yellow-600 hover:bg-yellow-700 rounded text-sm">Neuen Token generieren</button>
            <button @click="toggleActive(selectedWebhook)" class="flex-1 py-2 rounded text-sm" :class="selectedWebhook?.is_active ? 'bg-orange-600 hover:bg-orange-700' : 'bg-green-600 hover:bg-green-700'">
              {{ selectedWebhook?.is_active ? 'Deaktivieren' : 'Aktivieren' }}
            </button>
          </div>

          <div>
            <label class="text-sm text-slate-400 mb-2 block">Beispiel was n8n bekommt:</label>
            <pre class="bg-slate-900 p-4 rounded-lg overflow-x-auto text-xs text-green-400">{{ JSON.stringify(exampleResponse, null, 2) }}</pre>
          </div>
        </div>
      </div>
    </div>

    <div v-if="copied" class="fixed bottom-4 right-4 bg-green-600 px-4 py-2 rounded shadow-lg">URL kopiert!</div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api/client.js'

const webhooks = ref([])
const showModal = ref(false)
const showTokenModal = ref(false)
const showDetailsModal = ref(false)
const isEdit = ref(false)
const editId = ref(null)
const error = ref('')
const copied = ref(false)
const createdWebhook = ref(null)
const selectedWebhook = ref(null)
const expertMode = ref(false)

const allSeverities = ['emergency', 'alert', 'critical', 'error', 'warning', 'notice', 'info', 'debug']
const defaultForm = { name: '', description: '', filter_severities: ['emergency', 'alert', 'critical', 'error', 'warning', 'notice', 'info', 'debug'], filter_hostname: '', filter_source: '', max_results: 100, include_raw: false }
const form = ref({ ...defaultForm })

const exampleResponse = {
  webhook: "Mein-Webhook",
  count: 2,
  logs: [
    { id: 123, hostname: "server-01", level: "error", message: "Connection failed" },
    { id: 124, hostname: "server-02", level: "warning", message: "High CPU usage" }
  ]
}

function severityClass(sev) {
  const c = { emergency: 'bg-red-800', alert: 'bg-red-700', critical: 'bg-red-600', error: 'bg-orange-600', warning: 'bg-yellow-600', notice: 'bg-cyan-600', info: 'bg-blue-600', debug: 'bg-slate-600' }
  return c[sev] || 'bg-slate-600'
}

function formatDate(ts) { return ts ? new Date(ts).toLocaleString('de-DE') : '' }
function getWebhookUrl(wh) { return wh ? window.location.origin + '/api/webhook/' + wh.id + '/call?token=YOUR_TOKEN' : '' }

async function fetchWebhooks() { try { webhooks.value = (await api.get('/webhooks')).data } catch (e) { console.error(e) } }

function openCreate() {
  isEdit.value = false
  editId.value = null
  form.value = { ...defaultForm, filter_severities: [...defaultForm.filter_severities] }
  expertMode.value = false
  error.value = ''
  showModal.value = true
}

function openEdit(wh) {
  isEdit.value = true
  editId.value = wh.id
  form.value = {
    name: wh.name,
    description: wh.description || '',
    filter_severities: [...(wh.filter_severities || defaultForm.filter_severities)],
    filter_hostname: wh.filter_hostname || '',
    filter_source: wh.filter_source || '',
    max_results: wh.max_results || 100,
    include_raw: wh.include_raw || false
  }
  expertMode.value = !!(wh.filter_hostname || wh.filter_source || wh.filter_severities?.length < 8)
  error.value = ''
  showModal.value = true
}

function closeModal() { showModal.value = false; error.value = '' }

function prepareData() {
  return {
    name: form.value.name,
    description: form.value.description || null,
    filter_severities: form.value.filter_severities,
    filter_hostname: form.value.filter_hostname || null,
    filter_source: form.value.filter_source || null,
    max_results: form.value.max_results,
    include_raw: form.value.include_raw
  }
}

async function saveWebhook() {
  error.value = ''
  const data = prepareData()
  try {
    if (isEdit.value) {
      await api.put('/webhooks/' + editId.value, data)
      closeModal()
      fetchWebhooks()
    } else {
      const res = await api.post('/webhooks', data)
      createdWebhook.value = res.data
      closeModal()
      showTokenModal.value = true
    }
  } catch (e) {
    if (typeof e.message === 'object') {
      error.value = JSON.stringify(e.message)
    } else {
      error.value = e.message || 'Unbekannter Fehler'
    }
  }
}

async function toggleActive(wh) {
  try {
    await api.put('/webhooks/' + wh.id, { is_active: !wh.is_active })
    if (selectedWebhook.value) selectedWebhook.value.is_active = !wh.is_active
    fetchWebhooks()
  } catch (e) { console.error(e) }
}

async function deleteWebhook(id) {
  if (confirm('Webhook loeschen?')) {
    try { await api.delete('/webhooks/' + id); fetchWebhooks() }
    catch (e) { console.error(e) }
  }
}

function showDetails(wh) { selectedWebhook.value = wh; showDetailsModal.value = true }

async function regenerateToken() {
  if (!selectedWebhook.value) return
  if (confirm('Neuen Token generieren? Der alte funktioniert dann nicht mehr!')) {
    try {
      const res = await api.post('/webhooks/' + selectedWebhook.value.id + '/regenerate-token')
      alert('Neuer Token:\n\n' + res.data.token + '\n\nJetzt kopieren und speichern!')
      fetchWebhooks()
    } catch (e) { alert('Fehler: ' + e.message) }
  }
}

function copyUrl() {
  if (createdWebhook.value?.webhook_url) {
    navigator.clipboard.writeText(createdWebhook.value.webhook_url)
    copied.value = true
    setTimeout(() => copied.value = false, 2000)
  }
}

onMounted(fetchWebhooks)
</script>
WEBHOOKS_VUE_EOF

    log_ok "Frontend Webhooks.vue gepatcht"
}

rebuild_containers() {
    log_info "Baue Container neu..."
    cd "$INSTALL_DIR"
    docker compose build backend frontend
    docker compose up -d
    log_ok "Container neu gebaut und gestartet"
}

main() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         LogBot Patch v1.1.0 - Incoming Webhooks           ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    check_root
    check_logbot
    create_backup
    
    echo ""
    log_info "Anwenden der Patches..."
    echo ""
    
    patch_webhooks_backend
    patch_main_py
    patch_webhooks_frontend
    
    echo ""
    rebuild_containers
    
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   Patch erfolgreich!                       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "Neue Features:"
    echo -e "  ${BLUE}•${NC} Webhooks → n8n kann Logs per GET abrufen"
    echo -e "  ${BLUE}•${NC} Token-Authentifizierung"
    echo -e "  ${BLUE}•${NC} Einfach/Experten-Modus im UI"
    echo -e "  ${BLUE}•${NC} Filter: Severity, Hostname, Source"
    echo ""
    echo -e "Backup: ${YELLOW}$BACKUP_DIR${NC}"
    echo ""
    echo -e "n8n URL Format:"
    echo -e "  ${BLUE}http://LOGBOT/api/webhook/ID/call?token=TOKEN&since_minutes=60${NC}"
    echo ""
}

main "$@"
