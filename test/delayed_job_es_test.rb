require "test_helper"

class DelayedJobEsTest < Minitest::Test

  def test_commits_and_reloads_job
  	job = Delayed::Job.create payload_object: DelayedJobEs::DummyJob.new({:arguments => ["ab","b","c"]})
    assert_equal true, (job.reload.payload_object.class.name == "DelayedJobEs::DummyJob")
  end

  #def test_clears_locks
    #job = Delayed::Job.create payload_object: DelayedJobEs::DummyJob.new({:arguments => ["ab","b","c"]})
    #Delayed::Backend::Es::Job.clear_locks!
  #end

=begin
  def test_finds_applicable_job

  end

  def runs_job_and_destroys_it

  end

  def reschedules_job_on_failure

  end
=end
end
