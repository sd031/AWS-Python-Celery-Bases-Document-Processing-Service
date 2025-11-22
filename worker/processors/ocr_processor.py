import os
import logging
import boto3
from typing import Optional

logger = logging.getLogger(__name__)


class OCRProcessor:
    """Process documents using AWS Textract for OCR."""
    
    def __init__(self):
        self.textract_client = boto3.client(
            'textract',
            region_name=os.getenv('AWS_REGION', 'us-east-1')
        )
    
    def extract_text(self, bucket: str, key: str) -> Optional[str]:
        """
        Extract text from a document using AWS Textract.
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            Extracted text or None if extraction fails
        """
        try:
            # Detect document text
            response = self.textract_client.detect_document_text(
                Document={
                    'S3Object': {
                        'Bucket': bucket,
                        'Name': key
                    }
                }
            )
            
            # Extract text from blocks
            text_lines = []
            for block in response.get('Blocks', []):
                if block['BlockType'] == 'LINE':
                    text_lines.append(block.get('Text', ''))
            
            extracted_text = '\n'.join(text_lines)
            logger.info(f"Extracted {len(extracted_text)} characters from {key}")
            
            return extracted_text if extracted_text else None
            
        except self.textract_client.exceptions.InvalidS3ObjectException:
            logger.error(f"Invalid S3 object: {bucket}/{key}")
            return None
        except self.textract_client.exceptions.UnsupportedDocumentException:
            logger.warning(f"Unsupported document format: {key}")
            return None
        except Exception as e:
            logger.error(f"Textract error for {key}: {e}")
            return None
    
    def extract_text_with_tables(self, bucket: str, key: str) -> dict:
        """
        Extract text and tables from a document using AWS Textract.
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            Dictionary with text and table data
        """
        try:
            # Analyze document
            response = self.textract_client.analyze_document(
                Document={
                    'S3Object': {
                        'Bucket': bucket,
                        'Name': key
                    }
                },
                FeatureTypes=['TABLES', 'FORMS']
            )
            
            # Extract text
            text_lines = []
            tables = []
            
            for block in response.get('Blocks', []):
                if block['BlockType'] == 'LINE':
                    text_lines.append(block.get('Text', ''))
                elif block['BlockType'] == 'TABLE':
                    tables.append(self._parse_table(block, response['Blocks']))
            
            return {
                'text': '\n'.join(text_lines),
                'tables': tables
            }
            
        except Exception as e:
            logger.error(f"Textract analysis error for {key}: {e}")
            return {'text': None, 'tables': []}
    
    def _parse_table(self, table_block: dict, all_blocks: list) -> list:
        """Parse table structure from Textract blocks."""
        # This is a simplified table parser
        # In production, you'd want more sophisticated table extraction
        rows = []
        try:
            if 'Relationships' in table_block:
                for relationship in table_block['Relationships']:
                    if relationship['Type'] == 'CHILD':
                        for cell_id in relationship['Ids']:
                            cell_block = next(
                                (b for b in all_blocks if b['Id'] == cell_id),
                                None
                            )
                            if cell_block:
                                rows.append(cell_block.get('Text', ''))
        except Exception as e:
            logger.error(f"Table parsing error: {e}")
        
        return rows
