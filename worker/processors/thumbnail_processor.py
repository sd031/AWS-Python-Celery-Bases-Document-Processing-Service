import os
import logging
import subprocess
from typing import Optional
from PIL import Image

logger = logging.getLogger(__name__)


class ThumbnailProcessor:
    """Generate thumbnails for images and videos."""
    
    def __init__(self):
        self.thumbnail_size = tuple(
            map(int, os.getenv('THUMBNAIL_SIZE', '300,300').split(','))
        )
    
    def generate_thumbnail(self, file_path: str) -> Optional[str]:
        """
        Generate a thumbnail for an image or video file.
        
        Args:
            file_path: Path to the source file
            
        Returns:
            Path to the generated thumbnail or None if generation fails
        """
        file_ext = os.path.splitext(file_path)[1].lower()
        
        # Image files
        if file_ext in ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff']:
            return self._generate_image_thumbnail(file_path)
        
        # Video files
        elif file_ext in ['.mp4', '.mov', '.avi', '.mkv', '.webm']:
            return self._generate_video_thumbnail(file_path)
        
        # PDF files
        elif file_ext == '.pdf':
            return self._generate_pdf_thumbnail(file_path)
        
        else:
            logger.warning(f"Unsupported file type for thumbnail: {file_ext}")
            return None
    
    def _generate_image_thumbnail(self, file_path: str) -> Optional[str]:
        """Generate thumbnail for image files using PIL."""
        try:
            with Image.open(file_path) as img:
                # Convert to RGB if necessary
                if img.mode in ('RGBA', 'LA', 'P'):
                    img = img.convert('RGB')
                
                # Generate thumbnail
                img.thumbnail(self.thumbnail_size, Image.Resampling.LANCZOS)
                
                # Save thumbnail
                thumbnail_path = f"{file_path}_thumb.jpg"
                img.save(thumbnail_path, 'JPEG', quality=85)
                
                logger.info(f"Generated image thumbnail: {thumbnail_path}")
                return thumbnail_path
                
        except Exception as e:
            logger.error(f"Failed to generate image thumbnail: {e}")
            return None
    
    def _generate_video_thumbnail(self, file_path: str) -> Optional[str]:
        """Generate thumbnail for video files using ffmpeg."""
        try:
            thumbnail_path = f"{file_path}_thumb.jpg"
            
            # Use ffmpeg to extract frame at 1 second
            # Note: ffmpeg must be installed in the Docker image
            cmd = [
                'ffmpeg',
                '-i', file_path,
                '-ss', '00:00:01.000',
                '-vframes', '1',
                '-vf', f'scale={self.thumbnail_size[0]}:{self.thumbnail_size[1]}:force_original_aspect_ratio=decrease',
                '-y',
                thumbnail_path
            ]
            
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30
            )
            
            if result.returncode == 0 and os.path.exists(thumbnail_path):
                logger.info(f"Generated video thumbnail: {thumbnail_path}")
                return thumbnail_path
            else:
                logger.error(f"ffmpeg failed: {result.stderr.decode()}")
                return None
                
        except subprocess.TimeoutExpired:
            logger.error("Video thumbnail generation timed out")
            return None
        except FileNotFoundError:
            logger.error("ffmpeg not found. Install ffmpeg to generate video thumbnails.")
            return None
        except Exception as e:
            logger.error(f"Failed to generate video thumbnail: {e}")
            return None
    
    def _generate_pdf_thumbnail(self, file_path: str) -> Optional[str]:
        """Generate thumbnail for PDF files."""
        try:
            # Try using pdf2image if available
            try:
                from pdf2image import convert_from_path
                
                images = convert_from_path(
                    file_path,
                    first_page=1,
                    last_page=1,
                    dpi=150
                )
                
                if images:
                    img = images[0]
                    img.thumbnail(self.thumbnail_size, Image.Resampling.LANCZOS)
                    
                    thumbnail_path = f"{file_path}_thumb.jpg"
                    img.save(thumbnail_path, 'JPEG', quality=85)
                    
                    logger.info(f"Generated PDF thumbnail: {thumbnail_path}")
                    return thumbnail_path
                    
            except ImportError:
                logger.warning("pdf2image not available, trying alternative method")
            
            # Alternative: Use ImageMagick convert command
            thumbnail_path = f"{file_path}_thumb.jpg"
            cmd = [
                'convert',
                '-density', '150',
                f'{file_path}[0]',  # First page only
                '-resize', f'{self.thumbnail_size[0]}x{self.thumbnail_size[1]}',
                '-quality', '85',
                thumbnail_path
            ]
            
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30
            )
            
            if result.returncode == 0 and os.path.exists(thumbnail_path):
                logger.info(f"Generated PDF thumbnail: {thumbnail_path}")
                return thumbnail_path
            else:
                logger.error(f"ImageMagick convert failed: {result.stderr.decode()}")
                return None
                
        except Exception as e:
            logger.error(f"Failed to generate PDF thumbnail: {e}")
            return None
