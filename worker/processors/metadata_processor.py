import os
import logging
import subprocess
import json
from typing import Dict, Any
from datetime import datetime
from PIL import Image

logger = logging.getLogger(__name__)


class MetadataProcessor:
    """Extract metadata from various file types."""
    
    def extract_metadata(self, file_path: str, file_type: str) -> Dict[str, Any]:
        """
        Extract metadata from a file.
        
        Args:
            file_path: Path to the file
            file_type: MIME type of the file
            
        Returns:
            Dictionary containing metadata
        """
        metadata = {
            'file_size': os.path.getsize(file_path),
            'file_type': file_type,
            'extracted_at': datetime.utcnow().isoformat()
        }
        
        file_ext = os.path.splitext(file_path)[1].lower()
        
        try:
            if file_type.startswith('image/'):
                metadata.update(self._extract_image_metadata(file_path))
            elif file_type.startswith('video/'):
                metadata.update(self._extract_video_metadata(file_path))
            elif file_type == 'application/pdf':
                metadata.update(self._extract_pdf_metadata(file_path))
        except Exception as e:
            logger.error(f"Failed to extract metadata: {e}")
        
        return metadata
    
    def _extract_image_metadata(self, file_path: str) -> Dict[str, Any]:
        """Extract metadata from image files."""
        metadata = {}
        
        try:
            with Image.open(file_path) as img:
                metadata['width'] = img.width
                metadata['height'] = img.height
                metadata['format'] = img.format
                metadata['mode'] = img.mode
                
                # Extract EXIF data if available
                if hasattr(img, '_getexif') and img._getexif():
                    exif = img._getexif()
                    if exif:
                        metadata['exif'] = {
                            str(k): str(v) for k, v in exif.items()
                            if isinstance(v, (str, int, float))
                        }
                
                # Get info
                if hasattr(img, 'info'):
                    metadata['info'] = {
                        k: str(v) for k, v in img.info.items()
                        if isinstance(v, (str, int, float))
                    }
        
        except Exception as e:
            logger.error(f"Failed to extract image metadata: {e}")
        
        return metadata
    
    def _extract_video_metadata(self, file_path: str) -> Dict[str, Any]:
        """Extract metadata from video files using ffprobe."""
        metadata = {}
        
        try:
            # Use ffprobe to get video metadata
            cmd = [
                'ffprobe',
                '-v', 'quiet',
                '-print_format', 'json',
                '-show_format',
                '-show_streams',
                file_path
            ]
            
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30
            )
            
            if result.returncode == 0:
                data = json.loads(result.stdout.decode())
                
                # Extract format info
                if 'format' in data:
                    fmt = data['format']
                    metadata['duration'] = float(fmt.get('duration', 0))
                    metadata['bit_rate'] = int(fmt.get('bit_rate', 0))
                    metadata['format_name'] = fmt.get('format_name', '')
                
                # Extract video stream info
                for stream in data.get('streams', []):
                    if stream.get('codec_type') == 'video':
                        metadata['width'] = stream.get('width')
                        metadata['height'] = stream.get('height')
                        metadata['codec'] = stream.get('codec_name')
                        metadata['fps'] = eval(stream.get('r_frame_rate', '0/1'))
                        break
        
        except subprocess.TimeoutExpired:
            logger.error("Video metadata extraction timed out")
        except FileNotFoundError:
            logger.warning("ffprobe not found. Install ffmpeg to extract video metadata.")
        except Exception as e:
            logger.error(f"Failed to extract video metadata: {e}")
        
        return metadata
    
    def _extract_pdf_metadata(self, file_path: str) -> Dict[str, Any]:
        """Extract metadata from PDF files."""
        metadata = {}
        
        try:
            # Try using PyPDF2 if available
            try:
                from PyPDF2 import PdfReader
                
                with open(file_path, 'rb') as f:
                    pdf = PdfReader(f)
                    metadata['page_count'] = len(pdf.pages)
                    
                    # Extract PDF info
                    if pdf.metadata:
                        info = pdf.metadata
                        metadata['title'] = info.get('/Title', '')
                        metadata['author'] = info.get('/Author', '')
                        metadata['subject'] = info.get('/Subject', '')
                        metadata['creator'] = info.get('/Creator', '')
                        metadata['producer'] = info.get('/Producer', '')
                        
                        # Convert dates
                        if '/CreationDate' in info:
                            metadata['creation_date'] = str(info['/CreationDate'])
                        if '/ModDate' in info:
                            metadata['modification_date'] = str(info['/ModDate'])
                
            except ImportError:
                logger.warning("PyPDF2 not available for PDF metadata extraction")
            
            # Alternative: Use pdfinfo command
            if not metadata:
                try:
                    result = subprocess.run(
                        ['pdfinfo', file_path],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        timeout=10
                    )
                    
                    if result.returncode == 0:
                        output = result.stdout.decode()
                        for line in output.split('\n'):
                            if ':' in line:
                                key, value = line.split(':', 1)
                                metadata[key.strip().lower().replace(' ', '_')] = value.strip()
                
                except (subprocess.TimeoutExpired, FileNotFoundError):
                    pass
        
        except Exception as e:
            logger.error(f"Failed to extract PDF metadata: {e}")
        
        return metadata
