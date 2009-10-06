require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

def expect_setup_with(user, path)
  expect_command "ssh #{user}@#{@host} 'cd #{path} && sudo git clone #{@repository} #{@application} && sudo chown -R #{user} #{@application}'"
end

describe Inploy::Deploy do
  before :each do
    @object = Inploy::Deploy.new
    @object.user = @user = 'batman'
    @object.hosts = [@host = 'gothic']
    @object.path = @path = '/city'
    @object.repository = @repository = 'git://'
    @object.application = @application = "robin"
    stub_commands
    file_doesnt_exists 'init.sh'
  end

  context "on setup" do
    it "should clone the repository with the application name" do
      expect_setup_with @user, @path
      @object.remote_setup
    end

    it "should dont execute init.sh if doesnt exists" do
      dont_accept_command "ssh #{@user}@#{@host} 'cd #{@path}/#{@application} && .init.sh'"
      @object.remote_setup
    end

    it "should take /opt as the default path" do
      @object.path = nil
      expect_setup_with @user, '/opt'
      @object.remote_setup
    end

    it "should take root as the default user" do
      @object.user = nil
      expect_setup_with 'root', @path
      @object.remote_setup
    end

    it "should execute local setup" do
      expect_command "ssh #{@user}@#{@host} 'cd #{@path}/#{@application} && rake inploy:local:setup'"
      @object.remote_setup
    end
  end

  context "on local setup" do
    it "should run migrations" do
      expect_command "rake db:migrate RAILS_ENV=production"
      @object.local_setup
    end

    it "should run init.sh if exists" do
      file_exists "init.sh"
      expect_command "./init.sh"
      @object.local_setup
    end

    it "should run init.sh if doesnt exists" do
      file_doesnt_exists "init.sh"
      dont_accept_command "./init.sh"
      @object.local_setup
    end
  end

  it "should do a remote update running the inploy:update task" do
    expect_command "ssh #{@user}@#{@host} 'cd #{@path}/#{@application} && rake inploy:update'"
    @object.remote_update
  end

  it "should exec the commands in all hosts" do
    @object.hosts = ['host0', 'host1', 'host2']
    3.times.each do |i|
      expect_command "ssh #{@user}@host#{i} 'cd #{@path}/#{@application} && rake inploy:update'"
    end
    @object.remote_update
  end

  context "on local setup" do

  end

  context "on update" do
    before :each do
      stub_commands
    end

    it "should pull the repository" do
      expect_command "git pull origin master"
      @object.local_update
    end

    it "should run the migrations for production" do
      expect_command "rake db:migrate RAILS_ENV=production"
      @object.local_update
    end

    it "should restart the server" do
      expect_command "touch tmp/restart.txt"
      @object.local_update
    end

    it "should clean the public cache" do
      expect_command "rm -R -f public/cache"
      @object.local_update
    end

    it "should not package the assets if asset_packager exists" do
      dont_accept_command "rake asset:packager:build_all"
      @object.local_update
    end

    it "should package the assets if asset_packager exists" do
      @object.stub!(:tasks).and_return("rake acceptance rake asset:packager:build_all rake asset:packager:create_yml")
      expect_command "rake asset:packager:build_all"
      @object.local_update
    end
  end
end
