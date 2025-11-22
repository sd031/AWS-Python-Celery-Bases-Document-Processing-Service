from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # AWS Configuration
    aws_region: str = "us-east-1"
    aws_account_id: str
    
    # S3 Configuration
    s3_bucket_name: str
    s3_upload_prefix: str = "uploads/"
    s3_processed_prefix: str = "processed/"
    
    # Celery Configuration
    celery_broker_url: str = "sqs://"
    celery_result_backend: str = "dynamodb://"
    dynamodb_table_name: str = "celery-results"
    
    # SNS Configuration
    sns_topic_arn: Optional[str] = None
    
    # API Configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_workers: int = 4
    
    # Processing Configuration
    max_file_size: int = 104857600  # 100MB
    allowed_extensions: str = "pdf,png,jpg,jpeg,gif,mp4,mov,avi,webp,tiff,bmp"
    thumbnail_size: str = "300,300"
    
    # Environment
    environment: str = "development"
    log_level: str = "INFO"
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
