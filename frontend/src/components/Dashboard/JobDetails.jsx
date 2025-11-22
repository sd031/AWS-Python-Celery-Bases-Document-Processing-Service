import { useState, useEffect } from 'react';
import { documentsAPI } from '../../services/api';
import { 
  FileText, Clock, CheckCircle, XCircle, Loader, 
  Image, FileType, Calendar, User, Hash, Download 
} from 'lucide-react';

const statusConfig = {
  pending: { icon: Clock, color: 'text-yellow-600', bg: 'bg-yellow-50', label: 'Pending' },
  processing: { icon: Loader, color: 'text-blue-600', bg: 'bg-blue-50', label: 'Processing' },
  completed: { icon: CheckCircle, color: 'text-green-600', bg: 'bg-green-50', label: 'Completed' },
  failed: { icon: XCircle, color: 'text-red-600', bg: 'bg-red-50', label: 'Failed' },
};

export default function JobDetails({ job, onUpdate }) {
  const [details, setDetails] = useState(job);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setDetails(job);
    
    // Auto-refresh if processing
    if (job.status === 'processing' || job.status === 'pending') {
      const interval = setInterval(async () => {
        try {
          const updated = await documentsAPI.getResults(job.job_id);
          setDetails(updated);
          onUpdate(updated);
          
          // Stop polling if completed or failed
          if (updated.status === 'completed' || updated.status === 'failed') {
            clearInterval(interval);
          }
        } catch (error) {
          console.error('Failed to fetch job details:', error);
        }
      }, 3000); // Poll every 3 seconds

      return () => clearInterval(interval);
    }
  }, [job.job_id, job.status]);

  const handleRefresh = async () => {
    setLoading(true);
    try {
      const updated = await documentsAPI.getResults(details.job_id);
      setDetails(updated);
      onUpdate(updated);
    } catch (error) {
      console.error('Failed to refresh:', error);
    } finally {
      setLoading(false);
    }
  };

  const config = statusConfig[details.status] || statusConfig.pending;
  const StatusIcon = config.icon;

  return (
    <div className="bg-white rounded-lg shadow">
      {/* Header */}
      <div className="p-6 border-b border-gray-200">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center space-x-3">
              <FileText className="h-8 w-8 text-indigo-600" />
              <div>
                <h2 className="text-xl font-semibold text-gray-900">
                  {details.original_file || 'Document Details'}
                </h2>
                <p className="text-sm text-gray-500 mt-1">
                  Job ID: {details.job_id}
                </p>
              </div>
            </div>
          </div>
          <div className={`flex items-center space-x-2 px-3 py-1.5 rounded-full ${config.bg}`}>
            <StatusIcon className={`h-5 w-5 ${config.color} ${details.status === 'processing' ? 'animate-spin' : ''}`} />
            <span className={`text-sm font-medium ${config.color}`}>
              {config.label}
            </span>
          </div>
        </div>

        {/* Progress Bar */}
        {(details.status === 'processing' || details.status === 'pending') && details.progress !== undefined && (
          <div className="mt-4">
            <div className="flex justify-between text-sm text-gray-600 mb-2">
              <span>{details.message || 'Processing...'}</span>
              <span>{details.progress}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div
                className="bg-indigo-600 h-2 rounded-full transition-all duration-500"
                style={{ width: `${details.progress}%` }}
              />
            </div>
          </div>
        )}
      </div>

      {/* Content */}
      <div className="p-6 space-y-6">
        {/* Basic Info */}
        <div>
          <h3 className="text-sm font-medium text-gray-900 mb-3">Document Information</h3>
          <dl className="grid grid-cols-2 gap-4">
            <div>
              <dt className="text-xs text-gray-500 flex items-center">
                <FileType className="h-4 w-4 mr-1" />
                File Type
              </dt>
              <dd className="mt-1 text-sm font-medium text-gray-900">{details.file_type}</dd>
            </div>
            <div>
              <dt className="text-xs text-gray-500 flex items-center">
                <Hash className="h-4 w-4 mr-1" />
                File Size
              </dt>
              <dd className="mt-1 text-sm font-medium text-gray-900">
                {(details.file_size / 1024 / 1024).toFixed(2)} MB
              </dd>
            </div>
            <div>
              <dt className="text-xs text-gray-500 flex items-center">
                <Calendar className="h-4 w-4 mr-1" />
                Created
              </dt>
              <dd className="mt-1 text-sm font-medium text-gray-900">
                {new Date(details.created_at).toLocaleString()}
              </dd>
            </div>
            {details.completed_at && (
              <div>
                <dt className="text-xs text-gray-500 flex items-center">
                  <CheckCircle className="h-4 w-4 mr-1" />
                  Completed
                </dt>
                <dd className="mt-1 text-sm font-medium text-gray-900">
                  {new Date(details.completed_at).toLocaleString()}
                </dd>
              </div>
            )}
          </dl>
        </div>

        {/* Results */}
        {details.results && details.status === 'completed' && (
          <div className="space-y-4">
            <h3 className="text-sm font-medium text-gray-900">Processing Results</h3>
            
            {/* Metadata */}
            {details.results.metadata && (
              <div className="bg-gray-50 rounded-lg p-4">
                <h4 className="text-xs font-medium text-gray-700 mb-2">Metadata</h4>
                <dl className="grid grid-cols-2 gap-3 text-xs">
                  {Object.entries(details.results.metadata).map(([key, value]) => (
                    <div key={key}>
                      <dt className="text-gray-500 capitalize">{key.replace(/_/g, ' ')}</dt>
                      <dd className="text-gray-900 font-medium mt-0.5">
                        {typeof value === 'object' ? JSON.stringify(value) : String(value)}
                      </dd>
                    </div>
                  ))}
                </dl>
              </div>
            )}

            {/* Thumbnail */}
            {details.results.thumbnail_url && (
              <div className="bg-gray-50 rounded-lg p-4">
                <h4 className="text-xs font-medium text-gray-700 mb-2 flex items-center">
                  <Image className="h-4 w-4 mr-1" />
                  Thumbnail Preview
                </h4>
                <div className="mt-2 flex justify-center bg-white rounded-lg border border-gray-200 p-2">
                  <img 
                    src={details.results.thumbnail_url} 
                    alt="Document thumbnail"
                    className="max-w-full max-h-64 object-contain rounded"
                    onError={(e) => {
                      e.target.onerror = null;
                      e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="200" height="200"%3E%3Crect fill="%23f3f4f6" width="200" height="200"/%3E%3Ctext x="50%25" y="50%25" dominant-baseline="middle" text-anchor="middle" fill="%239ca3af" font-family="sans-serif" font-size="14"%3EImage not available%3C/text%3E%3C/svg%3E';
                    }}
                  />
                </div>
              </div>
            )}

            {/* OCR Text */}
            {details.results.ocr_text && (
              <div className="bg-gray-50 rounded-lg p-4">
                <h4 className="text-xs font-medium text-gray-700 mb-2">Extracted Text</h4>
                <div className="text-xs text-gray-900 max-h-64 overflow-y-auto whitespace-pre-wrap font-mono bg-white p-3 rounded border border-gray-200">
                  {details.results.ocr_text}
                </div>
              </div>
            )}

            {/* Labels */}
            {details.results.labels && details.results.labels.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-4">
                <h4 className="text-xs font-medium text-gray-700 mb-2">Image Labels</h4>
                <div className="flex flex-wrap gap-2">
                  {details.results.labels.map((label, idx) => (
                    <span
                      key={idx}
                      className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800"
                    >
                      {label.Name} ({label.Confidence?.toFixed(1)}%)
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Error */}
        {details.error && (
          <div className="bg-red-50 rounded-lg p-4">
            <h4 className="text-xs font-medium text-red-800 mb-2">Error</h4>
            <p className="text-xs text-red-700">{details.error}</p>
          </div>
        )}

        {/* Refresh Button */}
        <button
          onClick={handleRefresh}
          disabled={loading}
          className="w-full flex justify-center items-center py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
        >
          <Download className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
          {loading ? 'Refreshing...' : 'Refresh Status'}
        </button>
      </div>
    </div>
  );
}
