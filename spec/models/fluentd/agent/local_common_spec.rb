require 'spec_helper'
require 'fileutils'

describe 'Fluentd::Agent::LocalCommon' do
  let!(:now) { Time.zone.now }
  before { Timecop.freeze(now) }
  after { Timecop.return }

  subject { target_class.new.tap{|t| t.pid_file = pid_file_path} }

  let!(:target_class) { Struct.new(:pid_file){ include Fluentd::Agent::LocalCommon } }
  let!(:pid_file_path) { Rails.root.join('tmp', 'fluentd-test', 'local_common_test.pid').to_s }

  describe '#pid' do
    context 'no pid file exists' do
      its(:pid) { should be_nil }
    end

    context 'empty pid file given' do
      before { FileUtils.touch pid_file_path }
      after  { FileUtils.rm pid_file_path }

      its(:pid) { should be_nil }
    end

    context 'valid pid file given' do
      before { File.write pid_file_path, '9999' }
      after  { FileUtils.rm pid_file_path }

      its(:pid) { should eq(9999) }
    end
  end

  describe '#config_write', stub: :daemon do
    let(:config_contents) { <<-CONF.strip_heredoc }
      <source>
        type forward
        port 24224
      </source>
    CONF

    let(:new_config) { <<-CONF.strip_heredoc }
      <source>
        type http
        port 8899
      </source>
    CONF

    before do
      ::Settings.max_backup_files_count.times do |i|
        backpued_time = now - (i + 1).hours
        FileUtils.touch File.join(daemon.agent.config_backup_dir , "#{backpued_time.strftime('%Y%m%d_%H%M%S')}.conf")
      end

      daemon.agent.config_write config_contents #add before conf
      daemon.agent.config_write new_config #update conf
    end

    after do
      FileUtils.rm_r daemon.agent.config_backup_dir, force: true
    end

    it 'backed up old conf' do
      backup_file = File.join(daemon.agent.config_backup_dir, "#{now.strftime('%Y%m%d_%H%M%S')}.conf")
      expect(File.exists? backup_file).to be_truthy
      expect(File.read(backup_file)).to eq config_contents
    end

    it 'keep files num up to max' do
      backup_files = Dir.glob("#{daemon.agent.config_backup_dir}/*").sort
      expect(backup_files.size).to eq ::Settings.max_backup_files_count
    end
  end
end
