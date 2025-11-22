import os
import logging
import boto3
from typing import Dict, Any, List

logger = logging.getLogger(__name__)


class ImageAnalyzer:
    """Analyze images using AWS Rekognition."""
    
    def __init__(self):
        self.rekognition_client = boto3.client(
            'rekognition',
            region_name=os.getenv('AWS_REGION', 'us-east-1')
        )
        self.max_labels = int(os.getenv('MAX_LABELS', '10'))
        self.min_confidence = float(os.getenv('MIN_CONFIDENCE', '75.0'))
    
    def analyze_image(self, bucket: str, key: str) -> Dict[str, Any]:
        """
        Analyze an image using AWS Rekognition.
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            Dictionary containing analysis results
        """
        results = {}
        
        try:
            # Detect labels
            labels = self._detect_labels(bucket, key)
            results['labels'] = labels
            
            # Detect moderation labels
            moderation = self._detect_moderation_labels(bucket, key)
            results['moderation'] = moderation
            
            # Detect text (if any)
            text = self._detect_text(bucket, key)
            if text:
                results['detected_text'] = text
            
            logger.info(f"Analyzed image: {key}")
            
        except Exception as e:
            logger.error(f"Image analysis failed for {key}: {e}")
        
        return results
    
    def _detect_labels(self, bucket: str, key: str) -> List[str]:
        """Detect labels in an image."""
        try:
            response = self.rekognition_client.detect_labels(
                Image={
                    'S3Object': {
                        'Bucket': bucket,
                        'Name': key
                    }
                },
                MaxLabels=self.max_labels,
                MinConfidence=self.min_confidence
            )
            
            labels = [
                {
                    'name': label['Name'],
                    'confidence': round(label['Confidence'], 2)
                }
                for label in response.get('Labels', [])
            ]
            
            logger.info(f"Detected {len(labels)} labels in {key}")
            return labels
            
        except Exception as e:
            logger.error(f"Label detection failed: {e}")
            return []
    
    def _detect_moderation_labels(self, bucket: str, key: str) -> Dict[str, Any]:
        """Detect moderation labels (unsafe content)."""
        try:
            response = self.rekognition_client.detect_moderation_labels(
                Image={
                    'S3Object': {
                        'Bucket': bucket,
                        'Name': key
                    }
                },
                MinConfidence=self.min_confidence
            )
            
            moderation_labels = [
                {
                    'name': label['Name'],
                    'confidence': round(label['Confidence'], 2),
                    'parent_name': label.get('ParentName', '')
                }
                for label in response.get('ModerationLabels', [])
            ]
            
            is_safe = len(moderation_labels) == 0
            
            result = {
                'is_safe': is_safe,
                'labels': moderation_labels
            }
            
            if not is_safe:
                logger.warning(f"Detected {len(moderation_labels)} moderation issues in {key}")
            
            return result
            
        except Exception as e:
            logger.error(f"Moderation detection failed: {e}")
            return {'is_safe': True, 'labels': []}
    
    def _detect_text(self, bucket: str, key: str) -> List[Dict[str, Any]]:
        """Detect text in an image."""
        try:
            response = self.rekognition_client.detect_text(
                Image={
                    'S3Object': {
                        'Bucket': bucket,
                        'Name': key
                    }
                }
            )
            
            text_detections = [
                {
                    'text': detection['DetectedText'],
                    'confidence': round(detection['Confidence'], 2),
                    'type': detection['Type']
                }
                for detection in response.get('TextDetections', [])
                if detection['Confidence'] >= self.min_confidence
            ]
            
            if text_detections:
                logger.info(f"Detected {len(text_detections)} text items in {key}")
            
            return text_detections
            
        except Exception as e:
            logger.error(f"Text detection failed: {e}")
            return []
    
    def detect_faces(self, bucket: str, key: str) -> List[Dict[str, Any]]:
        """Detect faces in an image."""
        try:
            response = self.rekognition_client.detect_faces(
                Image={
                    'S3Object': {
                        'Bucket': bucket,
                        'Name': key
                    }
                },
                Attributes=['ALL']
            )
            
            faces = []
            for face in response.get('FaceDetails', []):
                face_info = {
                    'confidence': round(face['Confidence'], 2),
                    'age_range': face.get('AgeRange', {}),
                    'gender': face.get('Gender', {}).get('Value'),
                    'emotions': [
                        {
                            'type': emotion['Type'],
                            'confidence': round(emotion['Confidence'], 2)
                        }
                        for emotion in face.get('Emotions', [])
                    ]
                }
                faces.append(face_info)
            
            logger.info(f"Detected {len(faces)} faces in {key}")
            return faces
            
        except Exception as e:
            logger.error(f"Face detection failed: {e}")
            return []
