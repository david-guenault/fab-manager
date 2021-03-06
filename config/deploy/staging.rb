server "demo.fab-manager.com", :web, :app, :db, primary: true

set :domain, "demo.fab-manager.com"
set :application, "fabmanager_staging"
set :user, "admin"
set :port, 22
set :deploy_to, "/home/#{user}/apps/#{application}"
set :deploy_via, :remote_cache
set :use_sudo, false

set :scm, "git"
set :repository, "git@github.com:LaCasemate/fab-manager.git"
set :scm_user, "jarod022"
set :branch, "dev"

set :rails_env, 'staging'


namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx_staging.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init_staging.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    run "mkdir -p #{shared_path}/uploads"
    put File.read("config/database.yml.default"), "#{shared_path}/config/database.yml"
    puts "Now edit #{shared_path}/config/database.yml"
    put File.read("config/application.yml"), "#{shared_path}/config/application.yml"
    puts "Now edit #{shared_path}/config/application.yml and add your ENV vars"

  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_robots, roles: :app do
    run "rm -rf #{release_path}/public/robots.txt"
    run "ln -nfs #{shared_path}/robots.txt #{release_path}/public/robots.txt"
  end
  after "deploy:finalize_update", "deploy:symlink_robots"

  desc "Rake db:migrate"
  task :db_migrate, :roles => :app do
    run "cd #{current_path} && bundle exec rake db:migrate RAILS_ENV=staging"
  end
  after "deploy:create_symlink", "deploy:db_migrate"

  desc "load seed to bd"
  task :load_seed, :roles => :app do
    run "cd #{current_path} && bundle exec rake db:seed RAILS_ENV=staging"
  end

  namespace :assets do
    desc 'Run the precompile task locally and rsync with shared'
    task :precompile, :roles => :web, :except => { :no_release => true } do
      %x{bundle exec rake assets:precompile RAILS_ENV=staging}
      %x{rsync --recursive --times --rsh='ssh -p#{port}' --compress --human-readable --progress public/assets #{user}@#{domain}:#{shared_path}}
      %x{bundle exec rake assets:clean}
    end
  end

end
