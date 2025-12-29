#!/bin/bash
#===============================================================================
# LogBot Installer
#===============================================================================
# Autor:        PF
# Version:      2024-12-29_23:50:00
# Claude Model: Claude Opus 4 (claude-sonnet-4-20250514)
# 
# Beschreibung: 
#   Vollstaendiger Installer fuer LogBot - ein zentraler Log-Server
#   - Empfaengt Logs von Linux, Windows und Netzwerkgeraeten via Syslog
#   - Web-UI fuer Log-Analyse, Agents, Webhooks, User-Verwaltung
#   - Syslog-Server (UDP/TCP Port 514)
#   - PostgreSQL Datenbank
#   - Caddy Reverse Proxy
#   - Portainer Agent fuer Remote-Management
#
# Features:
#   - Auto-Discovery: Agents werden automatisch bei erstem Log erstellt
#   - UniFi Support: CEF-Format Parsing fuer Controller + APs
#   - IP-basierte Agent-Erkennung
#
# Voraussetzungen:
#   - Debian 12 / Ubuntu 22.04+
#   - Root oder sudo-Rechte
#   - Internetverbindung
#
# Usage: sudo bash logbot-install.sh
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/logbot"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

check_root() {
    [[ $EUID -ne 0 ]] && log_error "Dieses Skript muss als root ausgefuehrt werden (sudo)"
}

check_os() {
    [[ ! -f /etc/debian_version ]] && log_error "Nur Debian/Ubuntu wird unterstuetzt"
    log_ok "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_ok "Docker bereits installiert"
        return 0
    fi
    log_info "Installiere Docker..."
    apt-get update && apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable docker && systemctl start docker
    log_ok "Docker installiert"
}

create_directories() {
    log_info "Erstelle Verzeichnisse..."
    mkdir -p "$INSTALL_DIR"/{backend/app/{routes,models,config},frontend/src/{components,views,stores,api},syslog,caddy,db/init,data/{postgres,caddy_data,caddy_config}}
    log_ok "Verzeichnisse erstellt"
}

create_env() {
    log_info "Erstelle .env..."
    cat > "$INSTALL_DIR/.env" << 'EOF'
DB_HOST=postgres
DB_PORT=5432
DB_USER=logbot
DB_PASSWORD=DBPASS_PLACEHOLDER
DB_NAME=logbot
SECRET_KEY=SECRET_PLACEHOLDER
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
TIMEZONE=Europe/Berlin
EOF
    sed -i "s/DBPASS_PLACEHOLDER/$(openssl rand -hex 16)/" "$INSTALL_DIR/.env"
    sed -i "s/SECRET_PLACEHOLDER/$(openssl rand -hex 32)/" "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"
    log_ok ".env erstellt"
}

create_docker_compose() {
    log_info "Erstelle docker-compose.yml..."
    cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: logbot-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - logbot-net

  backend:
    build: ./backend
    container_name: logbot-backend
    restart: unless-stopped
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
      SECRET_KEY: ${SECRET_KEY}
      TZ: ${TIMEZONE:-UTC}
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - logbot-net

  frontend:
    build: ./frontend
    container_name: logbot-frontend
    restart: unless-stopped
    depends_on:
      - backend
    networks:
      - logbot-net

  syslog:
    build: ./syslog
    container_name: logbot-syslog
    restart: unless-stopped
    ports:
      - "514:514/udp"
      - "514:514/tcp"
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - logbot-net

  caddy:
    image: caddy:2-alpine
    container_name: logbot-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data/caddy_data:/data
      - ./data/caddy_config:/config
    depends_on:
      - backend
      - frontend
    networks:
      - logbot-net

  portainer-agent:
    image: portainer/agent:latest
    container_name: logbot-portainer-agent
    restart: unless-stopped
    ports:
      - "9001:9001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      - logbot-net

networks:
  logbot-net:
    driver: bridge
EOF
    log_ok "docker-compose.yml erstellt"
}

create_caddyfile() {
    cat > "$INSTALL_DIR/caddy/Caddyfile" << 'EOF'
:80 {
    handle /api/* {
        reverse_proxy backend:8000
    }
    handle {
        reverse_proxy frontend:80
    }
}
EOF
}

create_db_schema() {
    log_info "Erstelle DB Schema..."
    cat > "$INSTALL_DIR/db/init/001_schema.sql" << 'EOF'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'viewer',
    language VARCHAR(10) DEFAULT 'de',
    timezone VARCHAR(50) DEFAULT 'Europe/Berlin',
    theme VARCHAR(20) DEFAULT 'dark',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostname VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    os_type VARCHAR(20),
    api_key_hash VARCHAR(255),
    ip_address VARCHAR(45),
    last_seen TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'unknown',
    version VARCHAR(20),
    config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE logs (
    id BIGSERIAL,
    agent_id UUID REFERENCES agents(id) ON DELETE SET NULL,
    hostname VARCHAR(255) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    level VARCHAR(20),
    source VARCHAR(100),
    facility VARCHAR(50),
    message TEXT NOT NULL,
    raw_message TEXT,
    log_type VARCHAR(50) DEFAULT 'generic',
    metadata JSONB DEFAULT '{}',
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE logs_default PARTITION OF logs DEFAULT;

CREATE TABLE alert_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    conditions JSONB NOT NULL,
    severity VARCHAR(20) DEFAULT 'info',
    cooldown_minutes INT DEFAULT 5,
    last_triggered TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE webhooks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    url VARCHAR(500) NOT NULL,
    method VARCHAR(10) DEFAULT 'POST',
    headers JSONB DEFAULT '{}',
    payload_template TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50),
    entity_id VARCHAR(100),
    old_value JSONB,
    new_value JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_logs_timestamp ON logs (timestamp DESC);
CREATE INDEX idx_logs_hostname ON logs (hostname);
CREATE INDEX idx_logs_level ON logs (level);
CREATE INDEX idx_agents_hostname ON agents (hostname);
CREATE INDEX idx_agents_ip ON agents (ip_address);
CREATE INDEX idx_audit_timestamp ON audit_log (created_at DESC);

INSERT INTO settings (key, value, description) VALUES
('app_name', '"LogBot"', 'Application name'),
('timezone', '"Europe/Berlin"', 'Server timezone'),
('enable_audit_log', 'true', 'Log user actions'),
('default_retention_days', '90', 'Log retention days'),
('max_log_age_days', '90', 'Delete logs older than X days'),
('log_level', '"info"', 'Minimum log level to store'),
('max_logs_per_request', '1000', 'Maximum logs per API request'),
('agent_offline_timeout_minutes', '5', 'Mark agent offline after X minutes'),
('webhook_timeout_seconds', '10', 'Webhook request timeout');
EOF
    log_ok "DB Schema erstellt"
}

create_backend() {
    log_info "Erstelle Backend..."
    
    cat > "$INSTALL_DIR/backend/requirements.txt" << 'EOF'
fastapi==0.109.2
uvicorn[standard]==0.27.1
asyncpg==0.29.0
sqlalchemy[asyncio]==2.0.25
python-jose[cryptography]==3.3.0
passlib==1.7.4
bcrypt==4.0.1
python-multipart==0.0.9
pydantic==2.6.1
pydantic-settings==2.1.0
email-validator==2.1.0
httpx==0.26.0
orjson==3.9.13
EOF

    cat > "$INSTALL_DIR/backend/Dockerfile" << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
RUN useradd -m -u 1000 logbot && chown -R logbot:logbot /app
USER logbot
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    touch "$INSTALL_DIR/backend/app/__init__.py"
    
    cat > "$INSTALL_DIR/backend/app/config/__init__.py" << 'EOF'
from .settings import settings
from .database import engine, async_session, get_db, init_db, close_db
EOF

    cat > "$INSTALL_DIR/backend/app/config/settings.py" << 'EOF'
from pydantic_settings import BaseSettings
class Settings(BaseSettings):
    db_host: str = "postgres"
    db_port: int = 5432
    db_user: str = "logbot"
    db_password: str = ""
    db_name: str = "logbot"
    secret_key: str = "changeme"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440
    @property
    def database_url(self) -> str:
        return f"postgresql+asyncpg://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"
    class Config:
        env_file = ".env"
settings = Settings()
EOF

    cat > "$INSTALL_DIR/backend/app/config/database.py" << 'EOF'
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from .settings import settings
engine = create_async_engine(settings.database_url, echo=False, future=True)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()
async def get_db():
    async with async_session() as session:
        try: yield session
        finally: await session.close()
async def init_db(): pass
async def close_db(): await engine.dispose()
EOF

    cat > "$INSTALL_DIR/backend/app/models/__init__.py" << 'EOF'
from .user import User
EOF

    cat > "$INSTALL_DIR/backend/app/models/user.py" << 'EOF'
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
import uuid
from app.config.database import Base
class User(Base):
    __tablename__ = "users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), default="viewer")
    language = Column(String(10), default="de")
    timezone = Column(String(50), default="Europe/Berlin")
    theme = Column(String(20), default="dark")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
EOF

    touch "$INSTALL_DIR/backend/app/routes/__init__.py"

    cat > "$INSTALL_DIR/backend/app/routes/health.py" << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from app.config.database import get_db
router = APIRouter()
@router.get("/health")
async def health(): return {"status": "healthy", "components": {"api": "healthy"}}
@router.get("/health/db")
async def health_db(db: AsyncSession = Depends(get_db)):
    try:
        r = await db.execute(text("SELECT COUNT(*) FROM logs")); log_count = r.scalar() or 0
        r = await db.execute(text("SELECT COUNT(*) FROM agents")); agent_count = r.scalar() or 0
        r = await db.execute(text("SELECT COUNT(*) FROM users")); user_count = r.scalar() or 0
        r = await db.execute(text("SELECT pg_database_size(current_database())")); db_size = r.scalar() or 0
        return {"status": "healthy", "metrics": {"log_count": log_count, "agent_count": agent_count, "user_count": user_count, "db_size_bytes": db_size}}
    except Exception as e: return {"status": "unhealthy", "error": str(e)}
EOF

    cat > "$INSTALL_DIR/backend/app/routes/auth.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from typing import Optional
import uuid
from app.config.database import get_db
from app.config.settings import settings
from app.models.user import User
router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")
class Token(BaseModel):
    access_token: str
    token_type: str
    expires_in: int
class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    role: str
    language: str
    timezone: str
    theme: str
    class Config: from_attributes = True
def verify_password(plain, hashed): return pwd_context.verify(plain, hashed)
def hash_password(password): return pwd_context.hash(password)
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.access_token_expire_minutes))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)) -> User:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        user_id = payload.get("sub")
        if not user_id: raise HTTPException(401, "Invalid token")
    except JWTError: raise HTTPException(401, "Invalid token")
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user or not user.is_active: raise HTTPException(401, "Invalid user")
    return user
async def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin": raise HTTPException(403, "Admin required")
    return user
@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.username == form_data.username))
    user = result.scalar_one_or_none()
    if not user or not verify_password(form_data.password, user.password_hash): raise HTTPException(401, "Invalid credentials")
    if not user.is_active: raise HTTPException(403, "Account disabled")
    token = create_access_token(data={"sub": str(user.id)})
    return Token(access_token=token, token_type="bearer", expires_in=settings.access_token_expire_minutes * 60)
@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    return UserResponse(id=str(user.id), username=user.username, email=user.email, role=user.role, language=user.language, timezone=user.timezone, theme=user.theme)
EOF

    cat > "$INSTALL_DIR/backend/app/routes/users.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, EmailStr
from typing import List
import uuid
from app.config.database import get_db
from app.models.user import User
from app.routes.auth import require_admin, hash_password
router = APIRouter()
class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    role: str = "viewer"
class UserOut(BaseModel):
    id: str
    username: str
    email: str
    role: str
    is_active: bool
@router.get("", response_model=List[UserOut])
async def list_users(db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    result = await db.execute(select(User))
    return [UserOut(id=str(u.id), username=u.username, email=u.email, role=u.role, is_active=u.is_active) for u in result.scalars().all()]
@router.post("", response_model=UserOut)
async def create_user(data: UserCreate, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    result = await db.execute(select(User).where(User.username == data.username))
    if result.scalar_one_or_none(): raise HTTPException(400, "Username already exists")
    result = await db.execute(select(User).where(User.email == data.email))
    if result.scalar_one_or_none(): raise HTTPException(400, "Email already exists")
    user = User(username=data.username, email=data.email, password_hash=hash_password(data.password), role=data.role)
    db.add(user); await db.commit(); await db.refresh(user)
    return UserOut(id=str(user.id), username=user.username, email=user.email, role=user.role, is_active=user.is_active)
@router.delete("/{user_id}")
async def delete_user(user_id: str, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user: raise HTTPException(404, "User not found")
    if user.username == "admin": raise HTTPException(400, "Cannot delete admin user")
    await db.delete(user); await db.commit()
    return {"status": "deleted"}
EOF

    cat > "$INSTALL_DIR/backend/app/routes/agents.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import hashlib, secrets
from app.config.database import get_db
from app.routes.auth import get_current_user
from app.models.user import User
router = APIRouter()
class AgentCreate(BaseModel):
    ip_address: str
    display_name: str
    os_type: str = "syslog"
class AgentUpdate(BaseModel):
    display_name: Optional[str] = None
    os_type: Optional[str] = None
class AgentOut(BaseModel):
    id: str
    hostname: str
    display_name: Optional[str]
    os_type: Optional[str]
    status: str
    last_seen: Optional[datetime]
    ip_address: Optional[str]
@router.get("", response_model=List[AgentOut])
async def list_agents(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("SELECT id, hostname, display_name, os_type, status, last_seen, ip_address FROM agents ORDER BY COALESCE(display_name, hostname)"))
    return [AgentOut(id=str(r[0]), hostname=r[1], display_name=r[2], os_type=r[3], status=r[4], last_seen=r[5], ip_address=r[6]) for r in result.fetchall()]
@router.post("", response_model=dict)
async def create_agent(data: AgentCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("SELECT id FROM agents WHERE ip_address = :ip OR hostname = :ip"), {"ip": data.ip_address})
    if result.fetchone(): raise HTTPException(400, "Agent with this IP already exists")
    api_key = secrets.token_urlsafe(32)
    api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
    await db.execute(text("INSERT INTO agents (hostname, display_name, os_type, ip_address, api_key_hash, status) VALUES (:ip, :display_name, :os_type, :ip, :hash, 'offline')"),
        {"ip": data.ip_address, "display_name": data.display_name, "os_type": data.os_type, "hash": api_key_hash})
    await db.commit()
    return {"ip": data.ip_address, "api_key": api_key, "message": "Agent created"}
@router.put("/{agent_id}")
async def update_agent(agent_id: str, data: AgentUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("SELECT id FROM agents WHERE id = :id"), {"id": agent_id})
    if not result.fetchone(): raise HTTPException(404, "Agent not found")
    await db.execute(text("UPDATE agents SET display_name = :display_name, os_type = :os_type, updated_at = NOW() WHERE id = :id"),
        {"id": agent_id, "display_name": data.display_name, "os_type": data.os_type})
    await db.commit()
    return {"status": "updated"}
@router.post("/{agent_id}/regenerate-key")
async def regenerate_key(agent_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("SELECT hostname, display_name FROM agents WHERE id = :id"), {"id": agent_id})
    row = result.fetchone()
    if not row: raise HTTPException(404, "Agent not found")
    api_key = secrets.token_urlsafe(32)
    api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
    await db.execute(text("UPDATE agents SET api_key_hash = :hash, updated_at = NOW() WHERE id = :id"), {"id": agent_id, "hash": api_key_hash})
    await db.commit()
    return {"api_key": api_key, "hostname": row[1] or row[0]}
@router.delete("/{agent_id}")
async def delete_agent(agent_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    await db.execute(text("DELETE FROM logs WHERE agent_id = :id"), {"id": agent_id})
    await db.execute(text("DELETE FROM agents WHERE id = :id"), {"id": agent_id})
    await db.commit()
    return {"status": "deleted"}
EOF

    cat > "$INSTALL_DIR/backend/app/routes/logs.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import hashlib, io, csv, json
from app.config.database import get_db
router = APIRouter()
class LogEntry(BaseModel):
    hostname: str
    level: str
    message: str
    source: Optional[str] = None
    timestamp: Optional[datetime] = None
async def verify_api_key(request: Request, db: AsyncSession):
    auth = request.headers.get("X-API-Key")
    if not auth: raise HTTPException(401, "API key required")
    key_hash = hashlib.sha256(auth.encode()).hexdigest()
    result = await db.execute(text("SELECT id, hostname FROM agents WHERE api_key_hash = :hash"), {"hash": key_hash})
    agent = result.fetchone()
    if not agent: raise HTTPException(401, "Invalid API key")
    await db.execute(text("UPDATE agents SET last_seen = NOW(), status = 'online' WHERE id = :id"), {"id": agent[0]})
    await db.commit()
    return {"agent_id": agent[0], "hostname": agent[1]}
@router.post("/ingest")
async def ingest_logs(logs: List[LogEntry], request: Request, db: AsyncSession = Depends(get_db)):
    agent = await verify_api_key(request, db)
    for log in logs:
        await db.execute(text("INSERT INTO logs (agent_id, hostname, timestamp, level, source, message) VALUES (:agent_id, :hostname, :ts, :level, :source, :message)"),
            {"agent_id": agent["agent_id"], "hostname": log.hostname or agent["hostname"], "ts": log.timestamp or datetime.utcnow(), "level": log.level, "source": log.source, "message": log.message})
    await db.commit()
    return {"status": "ok", "count": len(logs)}
@router.get("")
async def get_logs(db: AsyncSession = Depends(get_db), limit: int = 100, offset: int = 0, level: Optional[str] = None, search: Optional[str] = None):
    where = []; params = {"limit": limit, "offset": offset}
    if level: where.append("level = :level"); params["level"] = level
    if search: where.append("message ILIKE :search"); params["search"] = f"%{search}%"
    where_clause = "WHERE " + " AND ".join(where) if where else ""
    result = await db.execute(text(f"SELECT COUNT(*) FROM logs {where_clause}"), params)
    total = result.scalar()
    result = await db.execute(text(f"SELECT id, hostname, timestamp, level, source, message FROM logs {where_clause} ORDER BY timestamp DESC LIMIT :limit OFFSET :offset"), params)
    logs = [{"id": r[0], "hostname": r[1], "timestamp": r[2].isoformat() if r[2] else None, "level": r[3], "source": r[4], "message": r[5]} for r in result.fetchall()]
    return {"total": total, "logs": logs}
@router.get("/live")
async def get_live_logs(db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("SELECT id, hostname, timestamp, level, source, message FROM logs ORDER BY timestamp DESC LIMIT 50"))
    return [{"id": r[0], "hostname": r[1], "timestamp": r[2].isoformat() if r[2] else None, "level": r[3], "source": r[4], "message": r[5]} for r in result.fetchall()]
@router.get("/stats")
async def get_stats(db: AsyncSession = Depends(get_db)):
    r = await db.execute(text("SELECT COUNT(*) FROM logs")); total = r.scalar() or 0
    r = await db.execute(text("SELECT COUNT(DISTINCT hostname) FROM logs")); hosts = r.scalar() or 0
    r = await db.execute(text("SELECT COUNT(*) FROM logs WHERE level IN ('error', 'critical') AND timestamp > NOW() - INTERVAL '24 hours'")); errors = r.scalar() or 0
    r = await db.execute(text("SELECT COUNT(*) FROM logs WHERE timestamp > NOW() - INTERVAL '1 hour'")); last_hour = r.scalar() or 0
    return {"total_logs": total, "unique_hosts": hosts, "errors": errors, "last_hour": last_hour}
@router.get("/export")
async def export_logs(format: str = "csv", limit: int = 10000, db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("SELECT id, hostname, timestamp, level, source, message FROM logs ORDER BY timestamp DESC LIMIT :limit"), {"limit": limit})
    rows = result.fetchall()
    if format == "json":
        data = [{"id": r[0], "hostname": r[1], "timestamp": r[2].isoformat() if r[2] else None, "level": r[3], "source": r[4], "message": r[5]} for r in rows]
        return StreamingResponse(io.BytesIO(json.dumps(data, indent=2).encode()), media_type="application/json", headers={"Content-Disposition": "attachment; filename=logs.json"})
    output = io.StringIO(); writer = csv.writer(output)
    writer.writerow(["id", "hostname", "timestamp", "level", "source", "message"])
    for r in rows: writer.writerow([r[0], r[1], r[2].isoformat() if r[2] else "", r[3], r[4], r[5]])
    return StreamingResponse(io.BytesIO(output.getvalue().encode()), media_type="text/csv", headers={"Content-Disposition": "attachment; filename=logs.csv"})
EOF

    cat > "$INSTALL_DIR/backend/app/routes/webhooks.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from typing import List
import httpx
from app.config.database import get_db
from app.routes.auth import get_current_user
from app.models.user import User
router = APIRouter()
class WebhookCreate(BaseModel):
    name: str
    url: str
    method: str = "POST"
class WebhookOut(BaseModel):
    id: str
    name: str
    url: str
    method: str
    is_active: bool
@router.get("", response_model=List[WebhookOut])
async def list_webhooks(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("SELECT id, name, url, method, is_active FROM webhooks"))
    return [WebhookOut(id=str(r[0]), name=r[1], url=r[2], method=r[3], is_active=r[4]) for r in result.fetchall()]
@router.post("", response_model=WebhookOut)
async def create_webhook(data: WebhookCreate, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("INSERT INTO webhooks (name, url, method) VALUES (:name, :url, :method) RETURNING id, name, url, method, is_active"),
        {"name": data.name, "url": data.url, "method": data.method})
    row = result.fetchone(); await db.commit()
    return WebhookOut(id=str(row[0]), name=row[1], url=row[2], method=row[3], is_active=row[4])
@router.post("/{webhook_id}/test")
async def test_webhook(webhook_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("SELECT url, method FROM webhooks WHERE id = :id"), {"id": webhook_id})
    row = result.fetchone()
    if not row: raise HTTPException(404, "Webhook not found")
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.request(row[1], row[0], json={"test": True})
            return {"success": True, "status_code": resp.status_code}
    except Exception as e: return {"success": False, "error": str(e)}
@router.delete("/{webhook_id}")
async def delete_webhook(webhook_id: str, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    await db.execute(text("DELETE FROM webhooks WHERE id = :id"), {"id": webhook_id}); await db.commit()
    return {"status": "deleted"}
EOF

    cat > "$INSTALL_DIR/backend/app/routes/settings.py" << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from typing import Any
from app.config.database import get_db
from app.routes.auth import get_current_user, require_admin
from app.models.user import User
import json
router = APIRouter()
class SettingUpdate(BaseModel):
    value: Any
@router.get("")
async def get_settings(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(text("SELECT key, value, description FROM settings"))
    return {r[0]: {"value": r[1], "description": r[2]} for r in result.fetchall()}
@router.put("/{key}")
async def update_setting(key: str, data: SettingUpdate, db: AsyncSession = Depends(get_db), user: User = Depends(require_admin)):
    await db.execute(text("UPDATE settings SET value = :value, updated_at = NOW() WHERE key = :key"), {"key": key, "value": json.dumps(data.value)})
    await db.commit()
    return {"status": "updated"}
@router.delete("/data/logs")
async def clear_all_logs(db: AsyncSession = Depends(get_db), user: User = Depends(require_admin)):
    await db.execute(text("TRUNCATE TABLE logs")); await db.commit()
    return {"status": "deleted", "message": "All logs cleared"}
@router.delete("/data/agents")
async def clear_all_agents(db: AsyncSession = Depends(get_db), user: User = Depends(require_admin)):
    await db.execute(text("TRUNCATE TABLE logs")); await db.execute(text("DELETE FROM agents")); await db.commit()
    return {"status": "deleted", "message": "All agents and logs cleared"}
@router.delete("/data/all")
async def clear_all_data(db: AsyncSession = Depends(get_db), user: User = Depends(require_admin)):
    await db.execute(text("TRUNCATE TABLE logs")); await db.execute(text("TRUNCATE TABLE audit_log"))
    await db.execute(text("DELETE FROM webhooks")); await db.execute(text("DELETE FROM alert_rules"))
    await db.execute(text("DELETE FROM agents")); await db.execute(text("DELETE FROM users WHERE username != 'admin'"))
    await db.commit()
    return {"status": "deleted", "message": "All data cleared (admin user kept)"}
@router.get("/stats")
async def get_system_stats(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    r = await db.execute(text("SELECT COUNT(*) FROM logs")); log_count = r.scalar() or 0
    r = await db.execute(text("SELECT COUNT(*) FROM agents")); agent_count = r.scalar() or 0
    r = await db.execute(text("SELECT COUNT(*) FROM users")); user_count = r.scalar() or 0
    r = await db.execute(text("SELECT COUNT(*) FROM webhooks")); webhook_count = r.scalar() or 0
    r = await db.execute(text("SELECT pg_database_size(current_database())")); db_size = r.scalar() or 0
    return {"logs": log_count, "agents": agent_count, "users": user_count, "webhooks": webhook_count, "db_size_bytes": db_size}
EOF

    cat > "$INSTALL_DIR/backend/app/main.py" << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from sqlalchemy import select
from passlib.context import CryptContext
from app.config.database import async_session, init_db, close_db
from app.models.user import User
from app.routes import health, auth, users, agents, logs, webhooks, settings
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
async def ensure_admin_user():
    async with async_session() as db:
        result = await db.execute(select(User).where(User.username == "admin"))
        if not result.scalar_one_or_none():
            admin = User(username="admin", email="admin@localhost", password_hash=pwd_context.hash("admin"), role="admin")
            db.add(admin); await db.commit()
            print("Created default admin user (admin/admin)")
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db(); await ensure_admin_user(); yield; await close_db()
app = FastAPI(title="LogBot API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(health.router, prefix="/api", tags=["health"])
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(agents.router, prefix="/api/agents", tags=["agents"])
app.include_router(logs.router, prefix="/api/logs", tags=["logs"])
app.include_router(webhooks.router, prefix="/api/webhooks", tags=["webhooks"])
app.include_router(settings.router, prefix="/api/settings", tags=["settings"])
EOF

    log_ok "Backend erstellt"
}

create_syslog() {
    log_info "Erstelle Syslog Server..."
    
    cat > "$INSTALL_DIR/syslog/requirements.txt" << 'EOF'
asyncpg==0.29.0
EOF

    cat > "$INSTALL_DIR/syslog/Dockerfile" << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq-dev gcc && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server.py .
EXPOSE 514/udp 514/tcp
CMD ["python", "-u", "server.py"]
EOF

    cat > "$INSTALL_DIR/syslog/server.py" << 'EOF'
import asyncio, os, re, json
from datetime import datetime, timezone
import asyncpg

DB_CONFIG = {"host": os.getenv("DB_HOST", "postgres"), "port": int(os.getenv("DB_PORT", 5432)),
    "user": os.getenv("DB_USER", "logbot"), "password": os.getenv("DB_PASSWORD", ""), "database": os.getenv("DB_NAME", "logbot")}
FACILITY = ["kern", "user", "mail", "daemon", "auth", "syslog", "lpr", "news", "uucp", "cron", "authpriv", "ftp", "ntp", "audit", "alert", "clock", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7"]
SEVERITY = ["emergency", "alert", "critical", "error", "warning", "notice", "info", "debug"]
pool = None

async def init_db():
    global pool
    for i in range(30):
        try: pool = await asyncpg.create_pool(**DB_CONFIG, min_size=2, max_size=10); print("Database connected"); return
        except Exception as e: print(f"DB connection attempt {i+1}/30 failed: {e}"); await asyncio.sleep(2)
    raise Exception("Could not connect to database")

def parse_unifi_ap_log(msg):
    msg = re.sub(r'^[a-f0-9]{12},[^:]+:\s*', '', msg)
    msg = re.sub(r'(\w+):\s*\1\[(\d+)\]:', r'\1[\2]:', msg)
    json_match = re.search(r'\{[^}]+\}', msg)
    if json_match:
        try:
            data = json.loads(json_match.group())
            if data.get("message_type") == "STA_ASSOC_TRACKER": return f"Client {data.get('mac', '?')} {data.get('event_type', '?')} on {data.get('vap', '?')}"
        except: pass
    event_match = re.search(r'EVENT_(\w+)\s+(\w+):\s*([0-9a-f:]+)\s*/\s*(\d+\.\d+\.\d+\.\d+)', msg, re.I)
    if event_match: return f"{event_match.group(1).replace('_', ' ')}: {event_match.group(3)} -> {event_match.group(4)} ({event_match.group(2)})"
    anomaly_match = re.search(r'log_sta_anomalies\(\):\s*(.+)', msg)
    if anomaly_match:
        parts = anomaly_match.group(1); sta = re.search(r'sta=([0-9a-f:]+)', parts); anomaly = re.search(r'anomalies=(\w+)', parts); sat = re.search(r'satisfaction_now=(\d+)', parts)
        if sta and anomaly: return f"Client {sta.group(1)} anomaly: {anomaly.group(1).replace('_', ' ')} (satisfaction: {sat.group(1) if sat else '?'}%)"
    return msg

def parse_unifi_cef(msg):
    severity = "info"
    sev_match = re.search(r'\|(\d+)\|[^|]+\|(\d+)\|', msg)
    if sev_match:
        cef_sev = int(sev_match.group(2))
        severity = "info" if cef_sev <= 3 else "warning" if cef_sev <= 6 else "error"
    event_match = re.search(r'\|(\d+)\|([^|]+)\|(\d+)\|', msg); event_name = event_match.group(2) if event_match else ""
    msg_match = re.search(r'\bmsg=(.+?)$', msg)
    if msg_match:
        clean_msg = msg_match.group(1).strip()
        if event_name and event_name not in clean_msg: clean_msg = f"[{event_name}] {clean_msg}"
        return clean_msg, severity
    return msg, severity

def parse_syslog(data, source_ip=None):
    try: msg = data.decode("utf-8", errors="replace").strip()
    except: msg = str(data)
    result = {"raw": msg, "facility": "user", "severity": "info", "hostname": source_ip or "unknown", "message": msg, "timestamp": datetime.now(timezone.utc), "source": "syslog"}
    pri_match = re.match(r"<(\d+)>", msg)
    if pri_match:
        pri = int(pri_match.group(1))
        result["facility"] = FACILITY[pri >> 3] if (pri >> 3) < len(FACILITY) else "unknown"
        result["severity"] = SEVERITY[pri & 7] if (pri & 7) < len(SEVERITY) else "info"
        msg = msg[pri_match.end():]
    ts_match = re.match(r"(\w{3}\s+\d+\s+\d+:\d+:\d+)\s+", msg)
    if ts_match: msg = msg[ts_match.end():]
    parts = msg.split(" ", 1); syslog_hostname = parts[0] if parts else "unknown"
    result["syslog_hostname"] = syslog_hostname; message_part = parts[1] if len(parts) > 1 else msg
    if "CEF:" in result["raw"] and "Ubiquiti" in result["raw"]:
        result["source"] = "unifi"
        host_match = re.search(r"UNIFIhost=(\S+)", result["raw"])
        if host_match: result["syslog_hostname"] = host_match.group(1)
        result["message"], result["severity"] = parse_unifi_cef(result["raw"])
    elif re.search(r'[a-f0-9]{12},\w+-\d+\.\d+\.\d+\+\d+:', message_part):
        result["source"] = "unifi-ap"; result["message"] = parse_unifi_ap_log(message_part)
    elif "kernel:" in msg or "systemd" in msg: result["source"] = "linux"; result["message"] = message_part
    elif "sshd" in msg or "sudo:" in msg: result["source"] = "auth"; result["message"] = message_part
    else: result["message"] = message_part
    return result

async def find_or_create_agent(source_ip, syslog_hostname, source_type="syslog"):
    async with pool.acquire() as conn:
        row = await conn.fetchrow("SELECT id, hostname, display_name FROM agents WHERE ip_address = $1", source_ip)
        if row:
            await conn.execute("UPDATE agents SET last_seen = NOW(), status = 'online' WHERE id = $1", row["id"])
            return row["id"], row["display_name"] or row["hostname"]
        row = await conn.fetchrow("INSERT INTO agents (hostname, display_name, os_type, status, ip_address) VALUES ($1, $2, $3, 'online', $1) RETURNING id", source_ip, syslog_hostname, source_type)
        print(f"New agent registered: {source_ip} ({syslog_hostname}) - {source_type}")
        return row["id"], syslog_hostname

async def store_log(parsed, source_ip=None):
    agent_id, display_name = await find_or_create_agent(source_ip, parsed.get("syslog_hostname", "unknown"), parsed.get("source", "syslog"))
    async with pool.acquire() as conn:
        await conn.execute("INSERT INTO logs (agent_id, hostname, timestamp, level, facility, source, message, raw_message, log_type) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'syslog')",
            agent_id, display_name, parsed["timestamp"], parsed["severity"], parsed["facility"], parsed.get("source", "syslog"), parsed["message"], parsed["raw"])

class SyslogUDP(asyncio.DatagramProtocol):
    def datagram_received(self, data, addr): asyncio.create_task(self.handle(data, addr))
    async def handle(self, data, addr):
        try: source_ip = addr[0] if addr else None; parsed = parse_syslog(data, source_ip); await store_log(parsed, source_ip)
        except Exception as e: print(f"UDP error from {addr}: {e}")

async def handle_tcp(reader, writer):
    addr = writer.get_extra_info("peername"); source_ip = addr[0] if addr else None
    try:
        while True:
            data = await reader.readline()
            if not data: break
            parsed = parse_syslog(data, source_ip); await store_log(parsed, source_ip)
    except Exception as e: print(f"TCP error from {addr}: {e}")
    finally: writer.close()

async def main():
    await init_db(); loop = asyncio.get_event_loop()
    await loop.create_datagram_endpoint(SyslogUDP, local_addr=("0.0.0.0", 514))
    tcp = await asyncio.start_server(handle_tcp, "0.0.0.0", 514)
    print("Syslog server running on UDP/TCP 514")
    await asyncio.gather(tcp.serve_forever())

if __name__ == "__main__": asyncio.run(main())
EOF

    log_ok "Syslog Server erstellt"
}

create_frontend() {
    log_info "Erstelle Frontend..."
    
    cat > "$INSTALL_DIR/frontend/Dockerfile" << 'EOF'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    cat > "$INSTALL_DIR/frontend/nginx.conf" << 'EOF'
server { listen 80; root /usr/share/nginx/html; index index.html; location / { try_files $uri $uri/ /index.html; } }
EOF

    cat > "$INSTALL_DIR/frontend/package.json" << 'EOF'
{"name":"logbot-frontend","version":"1.0.0","scripts":{"dev":"vite","build":"vite build","preview":"vite preview"},"dependencies":{"vue":"^3.4.15","vue-router":"^4.2.5","pinia":"^2.1.7"},"devDependencies":{"@vitejs/plugin-vue":"^5.0.3","autoprefixer":"^10.4.17","postcss":"^8.4.33","tailwindcss":"^3.4.1","vite":"^5.0.12"}}
EOF

    cat > "$INSTALL_DIR/frontend/vite.config.js" << 'EOF'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
export default defineConfig({ plugins: [vue()], server: { proxy: { '/api': 'http://localhost:8000' } } })
EOF

    cat > "$INSTALL_DIR/frontend/tailwind.config.js" << 'EOF'
export default { content: ['./index.html', './src/**/*.{vue,js}'], darkMode: 'class', theme: { extend: {} }, plugins: [] }
EOF

    cat > "$INSTALL_DIR/frontend/postcss.config.js" << 'EOF'
export default { plugins: { tailwindcss: {}, autoprefixer: {} } }
EOF

    cat > "$INSTALL_DIR/frontend/index.html" << 'EOF'
<!DOCTYPE html><html lang="de" class="dark"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>LogBot</title></head><body class="bg-slate-900 text-white"><div id="app"></div><script type="module" src="/src/main.js"></script></body></html>
EOF

    cat > "$INSTALL_DIR/frontend/src/main.js" << 'EOF'
import { createApp } from 'vue'; import { createPinia } from 'pinia'; import App from './App.vue'; import router from './router.js'; import './style.css'; createApp(App).use(createPinia()).use(router).mount('#app')
EOF

    cat > "$INSTALL_DIR/frontend/src/style.css" << 'EOF'
@tailwind base; @tailwind components; @tailwind utilities;
.log-debug { @apply text-gray-400; } .log-info { @apply text-blue-400; } .log-notice { @apply text-cyan-400; } .log-warning { @apply text-yellow-400; } .log-error { @apply text-red-400; } .log-critical { @apply text-red-600 font-bold; }
EOF

    cat > "$INSTALL_DIR/frontend/src/App.vue" << 'EOF'
<template><router-view /></template>
<script setup>
import { onMounted } from 'vue'; import { useAuthStore } from './stores/auth.js'; onMounted(() => useAuthStore().checkAuth())
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/router.js" << 'EOF'
import { createRouter, createWebHistory } from 'vue-router'; import { useAuthStore } from './stores/auth.js'
const routes = [
  { path: '/login', name: 'Login', component: () => import('./views/Login.vue') },
  { path: '/', component: () => import('./components/Layout.vue'), meta: { requiresAuth: true }, children: [
    { path: '', name: 'Dashboard', component: () => import('./views/Dashboard.vue') },
    { path: 'logs', name: 'Logs', component: () => import('./views/Logs.vue') },
    { path: 'agents', name: 'Agents', component: () => import('./views/Agents.vue') },
    { path: 'webhooks', name: 'Webhooks', component: () => import('./views/Webhooks.vue') },
    { path: 'users', name: 'Users', component: () => import('./views/Users.vue') },
    { path: 'settings', name: 'Settings', component: () => import('./views/Settings.vue') },
    { path: 'health', name: 'Health', component: () => import('./views/Health.vue') }
  ]}
]
const router = createRouter({ history: createWebHistory(), routes })
router.beforeEach((to, from, next) => { const auth = useAuthStore(); if (to.meta.requiresAuth && !auth.isAuthenticated) next('/login'); else if (to.path === '/login' && auth.isAuthenticated) next('/'); else next() })
export default router
EOF

    cat > "$INSTALL_DIR/frontend/src/stores/auth.js" << 'EOF'
import { defineStore } from 'pinia'; import { ref, computed } from 'vue'; import api from '../api/client.js'
export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('token')); const user = ref(null); const isAuthenticated = computed(() => !!token.value)
  async function login(username, password) { const formData = new URLSearchParams(); formData.append('username', username); formData.append('password', password); const res = await api.post('/auth/login', formData, { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }); token.value = res.data.access_token; localStorage.setItem('token', token.value); await fetchUser() }
  async function fetchUser() { if (!token.value) return; try { user.value = (await api.get('/auth/me')).data } catch { logout() } }
  function checkAuth() { if (token.value) fetchUser() }
  function logout() { token.value = null; user.value = null; localStorage.removeItem('token') }
  return { token, user, isAuthenticated, login, logout, checkAuth }
})
EOF

    cat > "$INSTALL_DIR/frontend/src/api/client.js" << 'EOF'
const BASE = '/api'
class Api {
  getHeaders() { const h = { 'Content-Type': 'application/json' }; const t = localStorage.getItem('token'); if (t) h['Authorization'] = 'Bearer ' + t; return h }
  async request(method, path, data, customHeaders = {}) { const opts = { method, headers: { ...this.getHeaders(), ...customHeaders } }; if (data) opts.body = data instanceof URLSearchParams ? data : JSON.stringify(data); const res = await fetch(BASE + path, opts); if (!res.ok) { const e = await res.json().catch(() => ({})); throw new Error(e.detail || 'HTTP ' + res.status) }; const text = await res.text(); return { data: text ? JSON.parse(text) : null, status: res.status } }
  get(path, params = {}) { const q = new URLSearchParams(params).toString(); return this.request('GET', q ? path + '?' + q : path) }
  post(path, data, opts = {}) { return this.request('POST', path, data, opts.headers) }
  put(path, data) { return this.request('PUT', path, data) }
  patch(path, data) { return this.request('PATCH', path, data) }
  delete(path) { return this.request('DELETE', path) }
}
export default new Api()
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Login.vue" << 'EOF'
<template><div class="min-h-screen flex items-center justify-center bg-slate-900"><div class="bg-slate-800 p-8 rounded-lg shadow-xl w-full max-w-md"><h1 class="text-3xl font-bold text-center mb-8 text-blue-500">LogBot</h1><form @submit.prevent="handleLogin" class="space-y-6"><div><label class="block text-sm text-slate-300 mb-2">Username</label><input v-model="username" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded text-white" required /></div><div><label class="block text-sm text-slate-300 mb-2">Password</label><input v-model="password" type="password" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded text-white" required /></div><div v-if="error" class="text-red-400 text-sm">{{ error }}</div><button type="submit" :disabled="loading" class="w-full py-2 bg-blue-600 hover:bg-blue-700 rounded font-medium disabled:opacity-50">{{ loading ? 'Logging in...' : 'Login' }}</button></form><p class="mt-6 text-center text-slate-500 text-sm">Default: admin / admin</p></div></div></template>
<script setup>
import { ref } from 'vue'; import { useRouter } from 'vue-router'; import { useAuthStore } from '../stores/auth.js'
const router = useRouter(); const auth = useAuthStore(); const username = ref(''); const password = ref(''); const error = ref(''); const loading = ref(false)
async function handleLogin() { error.value = ''; loading.value = true; try { await auth.login(username.value, password.value); router.push('/') } catch (e) { error.value = e.message } finally { loading.value = false } }
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Dashboard.vue" << 'EOF'
<template><div class="p-6"><h2 class="text-2xl font-bold mb-6">Dashboard</h2><div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8"><div class="bg-slate-800 p-6 rounded-lg"><p class="text-slate-400 text-sm">Total Logs</p><p class="text-3xl font-bold">{{ formatNumber(stats.total_logs) }}</p></div><div class="bg-slate-800 p-6 rounded-lg"><p class="text-slate-400 text-sm">Hosts</p><p class="text-3xl font-bold text-green-400">{{ stats.unique_hosts || 0 }}</p></div><div class="bg-slate-800 p-6 rounded-lg"><p class="text-slate-400 text-sm">Errors (24h)</p><p class="text-3xl font-bold text-red-400">{{ stats.errors || 0 }}</p></div><div class="bg-slate-800 p-6 rounded-lg"><p class="text-slate-400 text-sm">Last Hour</p><p class="text-3xl font-bold text-blue-400">{{ stats.last_hour || 0 }}</p></div></div><div class="bg-slate-800 rounded-lg p-6"><div class="flex justify-between mb-4"><h3 class="text-lg font-semibold">Recent Logs</h3><button @click="fetchLogs" class="px-3 py-1 bg-blue-600 rounded text-sm">Refresh</button></div><table class="w-full text-sm"><thead class="text-slate-400 border-b border-slate-600"><tr><th class="text-left py-2">Time</th><th class="text-left py-2">Host</th><th class="text-left py-2">Level</th><th class="text-left py-2">Message</th></tr></thead><tbody><tr v-for="log in logs" :key="log.id" class="border-b border-slate-700"><td class="py-2 text-slate-400">{{ formatTime(log.timestamp) }}</td><td class="py-2">{{ log.hostname }}</td><td class="py-2"><span :class="'log-' + log.level">{{ log.level }}</span></td><td class="py-2 truncate max-w-md">{{ log.message }}</td></tr></tbody></table></div></div></template>
<script setup>
import { ref, onMounted, onUnmounted } from 'vue'; import api from '../api/client.js'
const stats = ref({}); const logs = ref([]); let interval
function formatNumber(val) { return val ? val.toLocaleString() : '0' }
function formatTime(ts) { return ts ? new Date(ts).toLocaleTimeString() : '' }
async function fetchStats() { try { stats.value = (await api.get('/logs/stats')).data } catch {} }
async function fetchLogs() { try { logs.value = (await api.get('/logs/live')).data } catch {} }
onMounted(() => { fetchStats(); fetchLogs(); interval = setInterval(() => { fetchStats(); fetchLogs() }, 5000) })
onUnmounted(() => clearInterval(interval))
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Logs.vue" << 'EOF'
<template><div class="p-6"><div class="flex justify-between mb-6"><h2 class="text-2xl font-bold">Logs</h2><div class="flex gap-2"><button @click="exportCsv" class="px-4 py-2 bg-green-600 rounded">CSV</button><button @click="exportJson" class="px-4 py-2 bg-blue-600 rounded">JSON</button></div></div><div class="bg-slate-800 p-4 rounded-lg mb-6 flex gap-4"><input v-model="search" placeholder="Search..." class="px-4 py-2 bg-slate-900 border border-slate-600 rounded flex-1" @keyup.enter="fetchLogs" /><select v-model="level" class="px-4 py-2 bg-slate-900 border border-slate-600 rounded"><option value="">All Levels</option><option value="debug">debug</option><option value="info">info</option><option value="warning">warning</option><option value="error">error</option></select><button @click="fetchLogs" class="px-4 py-2 bg-blue-600 rounded">Search</button></div><div class="bg-slate-800 rounded-lg overflow-hidden"><table class="w-full text-sm"><thead class="bg-slate-700 text-slate-400"><tr><th class="text-left py-3 px-4">Timestamp</th><th class="text-left py-3 px-4">Host</th><th class="text-left py-3 px-4">Level</th><th class="text-left py-3 px-4">Message</th></tr></thead><tbody><tr v-for="log in logs" :key="log.id" class="border-b border-slate-700"><td class="py-2 px-4 text-slate-400 whitespace-nowrap">{{ formatDate(log.timestamp) }}</td><td class="py-2 px-4 whitespace-nowrap">{{ log.hostname }}</td><td class="py-2 px-4"><span :class="'log-' + log.level">{{ log.level }}</span></td><td class="py-2 px-4">{{ log.message }}</td></tr></tbody></table><div class="p-4 flex justify-between border-t border-slate-700"><span class="text-slate-400">Total: {{ total.toLocaleString() }}</span><div class="flex gap-2"><button @click="prevPage" :disabled="page === 0" class="px-3 py-1 bg-slate-700 rounded disabled:opacity-50">Prev</button><span class="px-3 py-1">{{ page + 1 }}</span><button @click="nextPage" :disabled="isLastPage" class="px-3 py-1 bg-slate-700 rounded disabled:opacity-50">Next</button></div></div></div></div></template>
<script setup>
import { ref, computed, onMounted } from 'vue'; import api from '../api/client.js'
const logs = ref([]); const total = ref(0); const page = ref(0); const search = ref(''); const level = ref('')
const isLastPage = computed(() => (page.value + 1) * 100 >= total.value)
function formatDate(ts) { return ts ? new Date(ts).toLocaleString() : '' }
async function fetchLogs() { const params = { limit: 100, offset: page.value * 100 }; if (search.value) params.search = search.value; if (level.value) params.level = level.value; const res = await api.get('/logs', params); logs.value = res.data.logs; total.value = res.data.total }
function prevPage() { if (page.value > 0) { page.value--; fetchLogs() } }
function nextPage() { if (!isLastPage.value) { page.value++; fetchLogs() } }
function exportCsv() { window.open('/api/logs/export?format=csv&limit=10000', '_blank') }
function exportJson() { window.open('/api/logs/export?format=json&limit=10000', '_blank') }
onMounted(fetchLogs)
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Agents.vue" << 'EOF'
<template><div class="p-6"><div class="flex justify-between mb-6"><h2 class="text-2xl font-bold">Agents</h2><button @click="openCreate" class="px-4 py-2 bg-blue-600 rounded">+ Add Agent</button></div><div class="grid gap-4"><div v-for="agent in agents" :key="agent.id" class="bg-slate-800 p-4 rounded-lg flex justify-between items-center"><div><div class="flex items-center gap-3"><span class="w-3 h-3 rounded-full" :class="agent.status === 'online' ? 'bg-green-500' : 'bg-red-500'"></span><span class="font-semibold">{{ agent.display_name || agent.hostname }}</span><span class="text-xs text-slate-500 bg-slate-700 px-2 py-0.5 rounded">{{ agent.os_type }}</span></div><div class="text-sm text-slate-400 mt-1">IP: {{ agent.ip_address || agent.hostname }} | Last: {{ formatDate(agent.last_seen) }}</div></div><div class="flex gap-2"><button @click="openEdit(agent)" class="px-3 py-1 bg-blue-600 rounded text-sm">Edit</button><button @click="regenerateKey(agent)" class="px-3 py-1 bg-yellow-600 rounded text-sm">New Key</button><button @click="deleteAgent(agent.id)" class="px-3 py-1 bg-red-600 rounded text-sm">Delete</button></div></div><div v-if="agents.length === 0" class="bg-slate-800 p-8 rounded-lg text-center text-slate-500"><p class="mb-2">No agents registered yet</p><p class="text-xs">Agents are auto-created when syslog data arrives</p></div></div><div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center"><div class="bg-slate-800 p-6 rounded-lg w-full max-w-md"><h3 class="text-xl font-bold mb-4">{{ isEdit ? 'Edit Agent' : 'Add New Agent' }}</h3><form @submit.prevent="saveAgent" class="space-y-4"><div><label class="block text-sm text-slate-400 mb-1">IP Address *</label><input v-model="form.ip_address" placeholder="192.168.1.100" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" :disabled="isEdit" required /></div><div><label class="block text-sm text-slate-400 mb-1">Display Name *</label><input v-model="form.display_name" placeholder="Friendly name" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" required /></div><div><label class="block text-sm text-slate-400 mb-1">OS / Type</label><select v-model="form.os_type" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded"><option value="linux">Linux</option><option value="windows">Windows</option><option value="unifi">UniFi</option><option value="firewall">Firewall</option><option value="switch">Switch</option><option value="router">Router</option><option value="syslog">Syslog Device</option><option value="other">Other</option></select></div><div v-if="createdKey" class="p-4 bg-green-900/50 border border-green-600 rounded"><p class="text-sm text-green-400 mb-2">API Key (only for API agents, not syslog):</p><code class="block p-2 bg-slate-900 rounded text-xs break-all select-all">{{ createdKey }}</code></div><div v-if="error" class="text-red-400 text-sm">{{ error }}</div><div class="flex gap-2"><button type="button" @click="closeModal" class="flex-1 py-2 bg-slate-700 rounded">{{ createdKey ? 'Close' : 'Cancel' }}</button><button v-if="!createdKey" type="submit" class="flex-1 py-2 bg-blue-600 rounded">{{ isEdit ? 'Save' : 'Create' }}</button></div></form></div></div></div></template>
<script setup>
import { ref, onMounted } from 'vue'; import api from '../api/client.js'
const agents = ref([]); const showModal = ref(false); const isEdit = ref(false); const editId = ref(null); const form = ref({ ip_address: '', display_name: '', os_type: 'syslog' }); const createdKey = ref(''); const error = ref('')
function formatDate(ts) { return ts ? new Date(ts).toLocaleString() : 'Never' }
async function fetchAgents() { try { agents.value = (await api.get('/agents')).data } catch (e) { console.error(e) } }
function openCreate() { isEdit.value = false; editId.value = null; form.value = { ip_address: '', display_name: '', os_type: 'syslog' }; createdKey.value = ''; error.value = ''; showModal.value = true }
function openEdit(agent) { isEdit.value = true; editId.value = agent.id; form.value = { ip_address: agent.ip_address || agent.hostname, display_name: agent.display_name || '', os_type: agent.os_type || 'syslog' }; createdKey.value = ''; error.value = ''; showModal.value = true }
async function saveAgent() { error.value = ''; try { if (isEdit.value) { await api.put('/agents/' + editId.value, form.value); closeModal() } else { const res = await api.post('/agents', form.value); createdKey.value = res.data.api_key }; fetchAgents() } catch (e) { error.value = e.message } }
async function regenerateKey(agent) { if (confirm('New API key for ' + (agent.display_name || agent.hostname) + '?')) { try { const res = await api.post('/agents/' + agent.id + '/regenerate-key'); openEdit(agent); createdKey.value = res.data.api_key } catch (e) { alert('Error: ' + e.message) } } }
function closeModal() { showModal.value = false; createdKey.value = ''; error.value = '' }
async function deleteAgent(id) { if (confirm('Delete this agent and all its logs?')) { await api.delete('/agents/' + id); fetchAgents() } }
onMounted(fetchAgents)
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Webhooks.vue" << 'EOF'
<template><div class="p-6"><div class="flex justify-between mb-6"><h2 class="text-2xl font-bold">Webhooks</h2><button @click="showCreate = true" class="px-4 py-2 bg-blue-600 rounded">+ Add</button></div><div class="grid gap-4"><div v-for="wh in webhooks" :key="wh.id" class="bg-slate-800 p-4 rounded-lg flex justify-between"><div><p class="font-semibold">{{ wh.name }}</p><p class="text-sm text-slate-400">{{ wh.method }} {{ wh.url }}</p></div><div class="flex gap-2"><button @click="testWebhook(wh.id)" class="px-3 py-1 bg-green-600 rounded text-sm">Test</button><button @click="deleteWebhook(wh.id)" class="px-3 py-1 bg-red-600 rounded text-sm">Delete</button></div></div><div v-if="webhooks.length === 0" class="bg-slate-800 p-8 rounded-lg text-center text-slate-500">No webhooks configured</div></div><div v-if="showCreate" class="fixed inset-0 bg-black/50 flex items-center justify-center"><div class="bg-slate-800 p-6 rounded-lg w-full max-w-md"><h3 class="text-xl font-bold mb-4">New Webhook</h3><form @submit.prevent="createWebhook" class="space-y-4"><input v-model="form.name" placeholder="Name" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" required /><input v-model="form.url" placeholder="https://..." class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" required /><select v-model="form.method" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded"><option value="POST">POST</option><option value="GET">GET</option></select><div class="flex gap-2"><button type="button" @click="showCreate = false" class="flex-1 py-2 bg-slate-700 rounded">Cancel</button><button type="submit" class="flex-1 py-2 bg-blue-600 rounded">Create</button></div></form></div></div></div></template>
<script setup>
import { ref, onMounted } from 'vue'; import api from '../api/client.js'
const webhooks = ref([]); const showCreate = ref(false); const form = ref({ name: '', url: '', method: 'POST' })
async function fetchWebhooks() { webhooks.value = (await api.get('/webhooks')).data }
async function createWebhook() { await api.post('/webhooks', form.value); showCreate.value = false; form.value = { name: '', url: '', method: 'POST' }; fetchWebhooks() }
async function testWebhook(id) { const r = await api.post('/webhooks/' + id + '/test'); alert(r.data.success ? 'OK!' : 'Error: ' + r.data.error) }
async function deleteWebhook(id) { if (confirm('Delete?')) { await api.delete('/webhooks/' + id); fetchWebhooks() } }
onMounted(fetchWebhooks)
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Users.vue" << 'EOF'
<template><div class="p-6"><div class="flex justify-between mb-6"><h2 class="text-2xl font-bold">Users</h2><button @click="showCreate = true" class="px-4 py-2 bg-blue-600 rounded">+ Add</button></div><div class="bg-slate-800 rounded-lg overflow-hidden"><table class="w-full"><thead class="bg-slate-700 text-slate-400"><tr><th class="text-left py-3 px-4">Username</th><th class="text-left py-3 px-4">Email</th><th class="text-left py-3 px-4">Role</th><th class="py-3 px-4"></th></tr></thead><tbody><tr v-for="u in users" :key="u.id" class="border-b border-slate-700"><td class="py-3 px-4">{{ u.username }}</td><td class="py-3 px-4 text-slate-400">{{ u.email }}</td><td class="py-3 px-4"><span class="px-2 py-1 rounded text-xs" :class="u.role === 'admin' ? 'bg-purple-600' : 'bg-slate-600'">{{ u.role }}</span></td><td class="py-3 px-4 text-right"><button v-if="u.username !== 'admin'" @click="deleteUser(u.id)" class="text-red-400">Delete</button></td></tr></tbody></table></div><div v-if="showCreate" class="fixed inset-0 bg-black/50 flex items-center justify-center"><div class="bg-slate-800 p-6 rounded-lg w-full max-w-md"><h3 class="text-xl font-bold mb-4">New User</h3><form @submit.prevent="createUser" class="space-y-4"><input v-model="form.username" placeholder="Username" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" required /><input v-model="form.email" type="email" placeholder="Email" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" required /><input v-model="form.password" type="password" placeholder="Password" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded" required /><select v-model="form.role" class="w-full px-4 py-2 bg-slate-900 border border-slate-600 rounded"><option value="viewer">Viewer</option><option value="editor">Editor</option><option value="admin">Admin</option></select><div v-if="error" class="text-red-400 text-sm">{{ error }}</div><div class="flex gap-2"><button type="button" @click="showCreate = false; error = ''" class="flex-1 py-2 bg-slate-700 rounded">Cancel</button><button type="submit" class="flex-1 py-2 bg-blue-600 rounded">Create</button></div></form></div></div></div></template>
<script setup>
import { ref, onMounted } from 'vue'; import api from '../api/client.js'
const users = ref([]); const showCreate = ref(false); const form = ref({ username: '', email: '', password: '', role: 'viewer' }); const error = ref('')
async function fetchUsers() { users.value = (await api.get('/users')).data }
async function createUser() { error.value = ''; try { await api.post('/users', form.value); showCreate.value = false; form.value = { username: '', email: '', password: '', role: 'viewer' }; fetchUsers() } catch (e) { error.value = e.message } }
async function deleteUser(id) { if (confirm('Delete?')) { await api.delete('/users/' + id); fetchUsers() } }
onMounted(fetchUsers)
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Settings.vue" << 'EOF'
<template><div class="p-6"><h2 class="text-2xl font-bold mb-6">Settings</h2><div class="space-y-6"><div class="bg-slate-800 p-6 rounded-lg"><h3 class="text-lg font-semibold mb-4 text-blue-400">General</h3><div class="space-y-4"><div v-if="settings.app_name" class="flex justify-between items-center py-2 border-b border-slate-700"><div><p class="font-medium">Application Name</p><p class="text-sm text-slate-400">{{ settings.app_name.description }}</p></div><input :value="cleanValue(settings.app_name.value)" @blur="updateSetting('app_name', $event.target.value)" class="px-3 py-2 bg-slate-900 border border-slate-600 rounded w-48" /></div><div v-if="settings.timezone" class="flex justify-between items-center py-2 border-b border-slate-700"><div><p class="font-medium">Timezone</p><p class="text-sm text-slate-400">{{ settings.timezone.description }}</p></div><input :value="cleanValue(settings.timezone.value)" @blur="updateSetting('timezone', $event.target.value)" class="px-3 py-2 bg-slate-900 border border-slate-600 rounded w-48" /></div></div></div><div class="bg-slate-800 p-6 rounded-lg"><h3 class="text-lg font-semibold mb-4 text-green-400">Log Settings</h3><div class="space-y-4"><div v-if="settings.default_retention_days" class="flex justify-between items-center py-2 border-b border-slate-700"><div><p class="font-medium">Retention Days</p><p class="text-sm text-slate-400">{{ settings.default_retention_days.description }}</p></div><input type="number" :value="settings.default_retention_days.value" @blur="updateSetting('default_retention_days', $event.target.value)" class="px-3 py-2 bg-slate-900 border border-slate-600 rounded w-48" /></div><div v-if="settings.log_level" class="flex justify-between items-center py-2 border-b border-slate-700"><div><p class="font-medium">Minimum Log Level</p><p class="text-sm text-slate-400">{{ settings.log_level.description }}</p></div><select :value="cleanValue(settings.log_level.value)" @change="updateSetting('log_level', $event.target.value)" class="px-3 py-2 bg-slate-900 border border-slate-600 rounded w-48"><option value="debug">debug</option><option value="info">info</option><option value="warning">warning</option><option value="error">error</option></select></div></div></div><div class="bg-slate-800 p-6 rounded-lg"><h3 class="text-lg font-semibold mb-4 text-purple-400">Agent Settings</h3><div v-if="settings.agent_offline_timeout_minutes" class="flex justify-between items-center py-2 border-b border-slate-700"><div><p class="font-medium">Offline Timeout (Minutes)</p><p class="text-sm text-slate-400">{{ settings.agent_offline_timeout_minutes.description }}</p></div><input type="number" :value="settings.agent_offline_timeout_minutes.value" @blur="updateSetting('agent_offline_timeout_minutes', $event.target.value)" class="px-3 py-2 bg-slate-900 border border-slate-600 rounded w-48" /></div></div><div class="bg-slate-800 p-6 rounded-lg"><h3 class="text-lg font-semibold mb-4 text-slate-400">Server Configuration</h3><p class="text-sm text-slate-500 mb-4">Read-only - change in docker-compose.yml</p><div class="grid grid-cols-2 gap-4 text-sm"><div class="bg-slate-900 p-3 rounded"><p class="text-slate-400">Syslog Port</p><p class="text-xl font-mono">514 (UDP/TCP)</p></div><div class="bg-slate-900 p-3 rounded"><p class="text-slate-400">Web Port</p><p class="text-xl font-mono">80 / 443</p></div><div class="bg-slate-900 p-3 rounded"><p class="text-slate-400">Portainer Agent</p><p class="text-xl font-mono">9001</p></div><div class="bg-slate-900 p-3 rounded"><p class="text-slate-400">Config Path</p><p class="text-xl font-mono">/opt/logbot</p></div></div></div><div class="bg-slate-800 p-6 rounded-lg border-2 border-red-600"><h3 class="text-lg font-semibold mb-4 text-red-500">Danger Zone</h3><div class="bg-slate-900 p-4 rounded mb-4"><div class="grid grid-cols-4 gap-4 text-center"><div><p class="text-2xl font-bold">{{ stats.logs?.toLocaleString() || 0 }}</p><p class="text-xs text-slate-500">Logs</p></div><div><p class="text-2xl font-bold">{{ stats.agents || 0 }}</p><p class="text-xs text-slate-500">Agents</p></div><div><p class="text-2xl font-bold">{{ stats.users || 0 }}</p><p class="text-xs text-slate-500">Users</p></div><div><p class="text-2xl font-bold">{{ formatBytes(stats.db_size_bytes) }}</p><p class="text-xs text-slate-500">DB Size</p></div></div></div><div class="flex gap-4"><button @click="clearLogs" class="px-4 py-2 bg-yellow-600 hover:bg-yellow-700 rounded">Clear Logs</button><button @click="clearAgents" class="px-4 py-2 bg-orange-600 hover:bg-orange-700 rounded">Clear Agents + Logs</button><button @click="clearAll" class="px-4 py-2 bg-red-600 hover:bg-red-700 rounded">Reset Everything</button></div></div></div><div v-if="saved" class="fixed bottom-4 right-4 bg-green-600 px-4 py-2 rounded shadow-lg">Saved!</div></div></template>
<script setup>
import { ref, onMounted } from 'vue'; import api from '../api/client.js'
const settings = ref({}); const stats = ref({}); const saved = ref(false)
function cleanValue(val) { return val === null || val === undefined ? '' : String(val).replace(/^"|"$/g, '') }
function formatBytes(bytes) { if (!bytes) return '0 B'; const k = 1024; const s = ['B', 'KB', 'MB', 'GB']; const i = Math.floor(Math.log(bytes) / Math.log(k)); return (bytes / Math.pow(k, i)).toFixed(1) + ' ' + s[i] }
async function fetchSettings() { try { settings.value = (await api.get('/settings')).data } catch (e) { console.error(e) } }
async function fetchStats() { try { stats.value = (await api.get('/settings/stats')).data } catch (e) { console.error(e) } }
async function updateSetting(key, val) { let finalVal = val; if (val === 'true' || val === true) finalVal = true; else if (val === 'false' || val === false) finalVal = false; else if (!isNaN(Number(val)) && val !== '') finalVal = Number(val); await api.put('/settings/' + key, { value: finalVal }); saved.value = true; setTimeout(() => saved.value = false, 2000); fetchSettings() }
async function clearLogs() { if (confirm('Delete ALL logs?') && confirm('Sure?')) { await api.delete('/settings/data/logs'); fetchStats(); alert('Done') } }
async function clearAgents() { if (confirm('Delete ALL agents + logs?') && confirm('Sure?')) { await api.delete('/settings/data/agents'); fetchStats(); alert('Done') } }
async function clearAll() { if (confirm('RESET EVERYTHING?') && confirm('LAST WARNING!')) { await api.delete('/settings/data/all'); fetchStats(); alert('Done') } }
onMounted(() => { fetchSettings(); fetchStats() })
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/views/Health.vue" << 'EOF'
<template><div class="p-6"><h2 class="text-2xl font-bold mb-6">System Health</h2><div class="grid md:grid-cols-2 gap-6"><div class="bg-slate-800 p-6 rounded-lg"><h3 class="text-lg font-semibold mb-4">API Status</h3><div class="flex items-center gap-4"><span class="w-8 h-8 rounded-full" :class="health.status === 'healthy' ? 'bg-green-500' : 'bg-yellow-500'"></span><p class="text-2xl font-bold capitalize">{{ health.status || 'Unknown' }}</p></div></div><div class="bg-slate-800 p-6 rounded-lg"><h3 class="text-lg font-semibold mb-4">Database</h3><div class="grid grid-cols-2 gap-4"><div><p class="text-slate-400 text-sm">Logs</p><p class="text-xl font-bold">{{ db.metrics?.log_count?.toLocaleString() || 0 }}</p></div><div><p class="text-slate-400 text-sm">Agents</p><p class="text-xl font-bold">{{ db.metrics?.agent_count || 0 }}</p></div><div><p class="text-slate-400 text-sm">Users</p><p class="text-xl font-bold">{{ db.metrics?.user_count || 0 }}</p></div><div><p class="text-slate-400 text-sm">Size</p><p class="text-xl font-bold">{{ formatBytes(db.metrics?.db_size_bytes) }}</p></div></div></div></div><button @click="fetchHealth" class="mt-6 px-4 py-2 bg-blue-600 rounded">Refresh</button></div></template>
<script setup>
import { ref, onMounted } from 'vue'; import api from '../api/client.js'
const health = ref({}); const db = ref({})
function formatBytes(bytes) { if (!bytes) return '0 B'; const k = 1024; const s = ['B', 'KB', 'MB', 'GB']; const i = Math.floor(Math.log(bytes) / Math.log(k)); return (bytes / Math.pow(k, i)).toFixed(1) + ' ' + s[i] }
async function fetchHealth() { try { health.value = (await api.get('/health')).data; db.value = (await api.get('/health/db')).data } catch (e) { console.error(e) } }
onMounted(fetchHealth)
</script>
EOF

    cat > "$INSTALL_DIR/frontend/src/components/Layout.vue" << 'EOF'
<template><div class="flex h-screen bg-slate-900"><aside class="w-64 bg-slate-800 border-r border-slate-700 flex flex-col"><div class="p-4 border-b border-slate-700"><h1 class="text-2xl font-bold text-blue-500">LogBot</h1></div><nav class="flex-1 p-4 space-y-1"><router-link v-for="item in menu" :key="item.path" :to="item.path" class="flex items-center px-4 py-2 rounded-lg transition-colors" :class="isActive(item.path) ? 'bg-blue-600 text-white' : 'text-slate-300 hover:bg-slate-700'">{{ item.name }}</router-link></nav><div class="p-4 border-t border-slate-700 flex justify-between items-center"><div><p class="text-sm font-medium">{{ auth.user?.username }}</p><p class="text-xs text-slate-400">{{ auth.user?.role }}</p></div><button @click="logout" class="text-slate-400 hover:text-white">Logout</button></div></aside><main class="flex-1 overflow-auto"><router-view /></main></div></template>
<script setup>
import { useRouter, useRoute } from 'vue-router'; import { useAuthStore } from '../stores/auth.js'
const router = useRouter(); const route = useRoute(); const auth = useAuthStore()
const menu = [{ path: '/', name: 'Dashboard' }, { path: '/logs', name: 'Logs' }, { path: '/agents', name: 'Agents' }, { path: '/webhooks', name: 'Webhooks' }, { path: '/users', name: 'Users' }, { path: '/settings', name: 'Settings' }, { path: '/health', name: 'Health' }]
function isActive(path) { return path === '/' ? route.path === '/' : route.path.startsWith(path) }
function logout() { auth.logout(); router.push('/login') }
</script>
EOF

    log_ok "Frontend erstellt"
}

main() {
    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║               LogBot Installer v1.0                       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    check_root; check_os; install_docker; create_directories; create_env
    create_docker_compose; create_caddyfile; create_db_schema
    create_backend; create_syslog; create_frontend
    log_info "Starte Container..."
    cd "$INSTALL_DIR" && docker compose up -d --build
    IP=$(hostname -I | awk '{print $1}')
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║               Installation abgeschlossen!                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    echo -e "Web UI:           ${BLUE}http://${IP}${NC}"
    echo -e "Login:            ${YELLOW}admin / admin${NC}"
    echo -e "Syslog:           ${BLUE}UDP/TCP 514${NC}"
    echo -e "Portainer Agent:  ${BLUE}Port 9001${NC}"
    echo -e "Verzeichnis:      ${BLUE}$INSTALL_DIR${NC}\n"
    echo -e "${YELLOW}WICHTIG: Admin-Passwort nach erstem Login aendern!${NC}\n"
}

main "$@"
