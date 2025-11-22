from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum


class JobStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class UploadResponse(BaseModel):
    job_id: str
    message: str
    s3_key: str
    file_size: int
    file_type: str


class StatusResponse(BaseModel):
    job_id: str
    status: JobStatus
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    progress: Optional[int] = None
    message: Optional[str] = None


class ProcessingResult(BaseModel):
    ocr_text: Optional[str] = None
    thumbnail_url: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    labels: Optional[List[str]] = None
    moderation: Optional[Dict[str, Any]] = None


class ResultsResponse(BaseModel):
    job_id: str
    status: JobStatus
    original_file: str
    file_type: str
    file_size: int
    results: Optional[ProcessingResult] = None
    error: Optional[str] = None
    created_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None


class HealthResponse(BaseModel):
    status: str
    version: str = "1.0.0"
    timestamp: datetime = Field(default_factory=datetime.utcnow)
