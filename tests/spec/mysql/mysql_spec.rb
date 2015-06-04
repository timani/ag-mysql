require 'serverspec'

set :backend, :exec

ENV['mysql_password'] = 'xi25oB'

RSpec::Matchers.define :match_key_value do |key, value|
  match do |actual|
    actual =~ /^\s*?#{key}\s*?=\s*?#{value}/
  end
end

mysql_hardening_file = '/etc/mysql/conf.d/hardening.cnf'

# set OS-dependent filenames and paths
  mysql_config_file = '/etc/my.cnf'
  mysql_config_path = '/etc/'
  mysql_data_path = '/var/lib/mysql/'
  mysql_log_path = '/var/log/'
  mysql_log_file = 'mysqld.log'
  mysql_log_group = 'mysql'
  mysql_log_dir_group = 'root'
  service_name = 'mysqld'

tmp_config_file = '/var/tmp/tmp-my.cnf'

describe service("#{service_name}") do
  it { should be_enabled }
  it { should be_running }
end

# temporarily combine config-files and remove spaces
describe 'Combining configfiles' do
  describe command("cat #{mysql_config_file} | tr -s [:space:]  > #{tmp_config_file}; cat #{mysql_hardening_file} | tr -s [:space:] >> #{tmp_config_file}") do
    its(:exit_status) { should eq 0 }
  end
end

describe 'Checking MySQL-databases for risky entries' do

  # DTAG SEC: Req 3.24-1 (keine Community-version)
  describe command("mysql -uroot -p#{ENV['mysql_password']} mysql -s -e 'select version();' | tail -1") do
    its(:stdout) { should_not match(/Community/) }
  end

  # DTAG SEC: Req 3.24-1 (version > 5)
  describe command("mysql -uroot -p#{ENV['mysql_password']} mysql -s -e 'select substring(version(),1,1);' | tail -1") do
    its(:stdout) { should match(/^5/) }
  end

  # DTAG SEC: Req 3.24-2 (keine default-datenbanken)
  describe command("mysql -uroot -p#{ENV['mysql_password']} -s -e 'show databases like \"test\";'") do
    its(:stdout) { should_not match(/test/) }
  end

  # DTAG SEC: Req 3.24-3 (keine anonymous-benutzer)
  describe command("mysql -uroot -p#{ENV['mysql_password']} mysql -s -e 'select count(*) from mysql.user where user=\"\";' | tail -1") do
    its(:stdout) { should match(/^0/) }
  end

  # DTAG SEC: Req 3.24-5 (keine benutzerkonten ohne kennwort)
  describe command("mysql -uroot -p#{ENV['mysql_password']} mysql -s -e 'select count(*) from mysql.user where length(password)=0 or password=\"\";' | tail -1") do
    its(:stdout) { should match(/^0/) }
  end

  # DTAG SEC: Req 3.24-23 (no grant privileges)
  describe command("mysql -uroot -p#{ENV['mysql_password']} mysql -s -e 'select count(*) from mysql.user where grant_priv=\"y\" and User!=\"root\" and User!=\"debian-sys-maint\";' | tail -1") do
    its(:stdout) { should match(/^0/) }
  end

  # DTAG SEC: Req 3.24-27 (keine host-wildcards)
  describe command("mysql -uroot -p#{ENV['mysql_password']} mysql -s -e 'select count(*) from mysql.user where host=\"%\"' | tail -1") do
    its(:stdout) { should match(/^0/) }
  end

  # DTAG SEC: Req 3.24-28 (root-login nur von localhost)
  describe command("mysql -uroot -p#{ENV['mysql_password']} mysql -s -e 'select count(*) from mysql.user where user=\"root\" and host not in (\"localhost\",\"127.0.0.1\",\"::1\")' | tail -1") do
    its(:stdout) { should match(/^0/) }
  end

end

# DTAG SEC: Req 3.24-4 (nur eine instanz pro server)
describe 'Check for multiple instances' do
  describe command('ps aux | grep mysqld | egrep -v "grep|mysqld_safe|logger" | wc -l') do
    its(:stdout) { should match(/^1$/) }
  end
end

describe 'Parsing configfiles for unwanted entries' do

  # DTAG SEC: Req 3.24-6 (safe-user-create = 1)
  describe file(tmp_config_file) do
    its(:content) { should match_key_value('safe-user-create', '1') }
  end

  # DTAG SEC: Req 3.24-7 (no old_passwords)
  describe file(tmp_config_file) do
    its(:content) { should_not match_key_value('old_passwords', '1') }
  end

  # DTAG SEC: Req 3.24-8 (secure-auth = 1)
  describe file(tmp_config_file) do
    its(:content) { should match_key_value('secure-auth', '1') }
  end

  # DTAG SEC: Req 3.24-15 (secure-file-priv)
  describe file(tmp_config_file) do
    its(:content) { should match(/^\s*?secure-file-priv/) }
  end

end

# DTAG SEC: Req 3.24-17, SEC: Req 3.24-18, SEC: Req 3.24-19
describe 'Mysql-data owner, group and permissions' do

  describe file(mysql_data_path) do
    it { should be_directory }
    it { should be_owned_by 'mysql' }
    it { should be_grouped_into 'mysql' }
  end

  describe file("#{mysql_data_path}/ibdata1") do
    it { should be_owned_by 'mysql' }
    it { should be_grouped_into 'mysql' }
    it { should_not be_readable.by('others') }
    it { should_not be_writable.by('others') }
    it { should_not be_executable.by('others') }
  end

  describe file(mysql_log_path) do
    it { should be_directory }
    it { should be_owned_by 'root' }
    it { should be_grouped_into mysql_log_dir_group }
  end

  describe file("#{mysql_log_path}/#{mysql_log_file}") do
    it { should be_owned_by 'mysql' }
    it { should be_grouped_into mysql_log_group }
    it { should_not be_readable.by('others') }
    it { should_not be_writable.by('others') }
    it { should_not be_executable.by('others') }
  end

end

describe 'Mysql-config: owner, group and permissions' do

  describe file(mysql_config_path) do
    it { should be_directory }
  end

  describe file(mysql_config_path) do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
  end

  describe file(mysql_config_file) do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
  end

end

describe 'Mysql environment' do

  # DTAG SEC: 3.24-9
  describe command('env') do
    its(:stdout) { should_not match(/^MYSQL_PWD=/) }
  end

end
