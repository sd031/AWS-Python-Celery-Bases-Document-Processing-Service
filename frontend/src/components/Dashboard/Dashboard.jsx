import { useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import { documentsAPI } from '../../services/api';
import UploadZone from './UploadZone';
import JobsList from './JobsList';
import JobDetails from './JobDetails';
import { LogOut, FileText } from 'lucide-react';

export default function Dashboard() {
  const { user, logout } = useAuth();
  const [jobs, setJobs] = useState([]);
  const [selectedJob, setSelectedJob] = useState(null);
  const [loading, setLoading] = useState(false);

  const loadJobs = async () => {
    try {
      setLoading(true);
      const data = await documentsAPI.listJobs();
      setJobs(data.jobs || []);
    } catch (error) {
      console.error('Failed to load jobs:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadJobs();
  }, []);

  const handleUploadSuccess = (jobData) => {
    setJobs([jobData, ...jobs]);
    setSelectedJob(jobData);
  };

  const handleJobSelect = (job) => {
    setSelectedJob(job);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <div className="flex items-center space-x-3">
              <div className="h-10 w-10 rounded-lg bg-indigo-600 flex items-center justify-center">
                <FileText className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">Document Processor</h1>
                <p className="text-sm text-gray-500">Process documents with AI</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-right">
                <p className="text-sm font-medium text-gray-900">{user?.name}</p>
                <p className="text-xs text-gray-500">{user?.email}</p>
              </div>
              <button
                onClick={logout}
                className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                <LogOut className="h-4 w-4 mr-2" />
                Logout
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Upload and Jobs List */}
          <div className="lg:col-span-1 space-y-6">
            <UploadZone onUploadSuccess={handleUploadSuccess} />
            <JobsList
              jobs={jobs}
              selectedJob={selectedJob}
              onJobSelect={handleJobSelect}
              loading={loading}
              onRefresh={loadJobs}
            />
          </div>

          {/* Job Details */}
          <div className="lg:col-span-2">
            {selectedJob ? (
              <JobDetails job={selectedJob} onUpdate={(updatedJob) => {
                setSelectedJob(updatedJob);
                setJobs(jobs.map(j => j.job_id === updatedJob.job_id ? updatedJob : j));
              }} />
            ) : (
              <div className="bg-white rounded-lg shadow p-12 text-center">
                <FileText className="h-16 w-16 text-gray-300 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 mb-2">No document selected</h3>
                <p className="text-gray-500">Upload a document or select one from the list to view details</p>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
