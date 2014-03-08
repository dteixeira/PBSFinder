PbsSite::App.controllers :jobs do

  get :new do
    @job = Job.new
    @big_title = t('job.big_title.new')
    render :new
  end

  post :create do
    @job = Job.new(params[:job])
    @job.completed = false
    @job.account = current_account
    if server_running?
      if @job.save
        ids = prepare_ids(@job.query)
        long_job('PbsFinder', absolute_url(:jobs, :job, @job.id), ids)
        flash[:success] = t('job.create.success')
        redirect(url_for(:jobs, :job, @job.id))
      else
        @big_title = t('job.big_title.new')
        flash.now[:error] = t('job.create.error', :model => 'job')
        render :new
      end
    else
      flash.now[:error] = t('job.create.no_server', :model => 'job')
      render :new
    end
  end

  get :list do
    @jobs = current_account.jobs.where(completed: true).desc(:created_at)
    @jobs = @jobs.paginate(:page => params[:page] || 1, :per_page => 10)
    @completed = true
    @big_title = t('job.big_title.list')
    render :list
  end

  get :pending do
    @jobs = current_account.jobs.where(completed: false).desc(:created_at)
    @jobs = @jobs.paginate(:page => params[:page] || 1, :per_page => 10)
    @completed = false
    @big_title = t('job.big_title.pending')
    render :list
  end

  get :job, :with => :id do
    # TODO DISPLAY JOB
  end

  delete :destroy, :with => :id do
    job = Job.find(params[:id])
    if job
      job.destroy
      flash[:success] = t('job.destroy.success')
      redirect back
    else
      flash[:error] = t('job.destroy.error')
      redirect back
    end
  end

  delete :destroy_many do
    unless params[:job_ids]
      flash[:error] = t('job.destroy_many.error', :model => 'account')
      redirect back
    end
    ids = params[:job_ids].split(',').map(&:strip)
    jobs = Job.find(ids)
    jobs.each(&:destroy)
    flash[:success] = t('job.destroy_many.success')
    redirect back
  end

  post :job, :with => :id, :csrf_protection => false do
    job = Job.find(params[:id])
    if job
      json = JSON.parse(params[:result][:tempfile].read)
      if json['species']
        # TODO CREATE RESULTS
        job.species = json['species'].split("_").each_with_index.map { |x, i| i == 0 ? x.capitalize : x }.join(" ")
        job.completed = true
      else
        # Invalid job.
        job.completed = true
        job.save
      end
    end
  end

end
