import { RefreshCw, FileText, Clock, CheckCircle, XCircle, Loader } from 'lucide-react';

const statusIcons = {
  pending: Clock,
  processing: Loader,
  completed: CheckCircle,
  failed: XCircle,
};

const statusColors = {
  pending: 'text-yellow-600 bg-yellow-50',
  processing: 'text-blue-600 bg-blue-50',
  completed: 'text-green-600 bg-green-50',
  failed: 'text-red-600 bg-red-50',
};

export default function JobsList({ jobs, selectedJob, onJobSelect, loading, onRefresh }) {
  return (
    <div className="bg-white rounded-lg shadow">
      <div className="p-4 border-b border-gray-200 flex justify-between items-center">
        <h2 className="text-lg font-semibold text-gray-900">Recent Jobs</h2>
        <button
          onClick={onRefresh}
          disabled={loading}
          className="p-2 text-gray-400 hover:text-gray-600 disabled:opacity-50"
        >
          <RefreshCw className={`h-5 w-5 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      <div className="divide-y divide-gray-200 max-h-96 overflow-y-auto">
        {jobs.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <FileText className="h-12 w-12 text-gray-300 mx-auto mb-2" />
            <p className="text-sm">No documents yet</p>
            <p className="text-xs mt-1">Upload your first document to get started</p>
          </div>
        ) : (
          jobs.map((job) => {
            const StatusIcon = statusIcons[job.status] || Clock;
            const isSelected = selectedJob?.job_id === job.job_id;

            return (
              <button
                key={job.job_id}
                onClick={() => onJobSelect(job)}
                className={`w-full p-4 text-left hover:bg-gray-50 transition-colors ${
                  isSelected ? 'bg-indigo-50 border-l-4 border-indigo-600' : ''
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {job.original_file || job.s3_key?.split('/').pop() || 'Unnamed'}
                    </p>
                    <p className="text-xs text-gray-500 mt-1">
                      {new Date(job.created_at).toLocaleString()}
                    </p>
                  </div>
                  <div className={`ml-3 flex-shrink-0 p-1.5 rounded-full ${statusColors[job.status]}`}>
                    <StatusIcon className={`h-4 w-4 ${job.status === 'processing' ? 'animate-spin' : ''}`} />
                  </div>
                </div>
                {job.progress !== undefined && job.status === 'processing' && (
                  <div className="mt-2">
                    <div className="w-full bg-gray-200 rounded-full h-1.5">
                      <div
                        className="bg-indigo-600 h-1.5 rounded-full transition-all duration-300"
                        style={{ width: `${job.progress}%` }}
                      />
                    </div>
                    <p className="text-xs text-gray-500 mt-1">{job.progress}% - {job.message}</p>
                  </div>
                )}
              </button>
            );
          })
        )}
      </div>
    </div>
  );
}
