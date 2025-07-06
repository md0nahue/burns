require 'open3'
require 'json'
require_relative '../../config/services'

class AWSProvisioner
  def initialize
    @script_path = File.join(File.dirname(__FILE__), '../../scripts/provision_aws_infrastructure.sh')
  end

  # Provision all AWS infrastructure
  # @param options [Hash] Provisioning options
  # @return [Hash] Provisioning result
  def provision_infrastructure(options = {})
    puts "🚀 Provisioning AWS infrastructure..."
    
    # Validate AWS credentials
    validate_aws_credentials
    
    # Set environment variables
    env_vars = build_environment_variables(options)
    
    # Run provisioning script
    result = run_provisioning_script(env_vars)
    
    if result[:success]
      puts "✅ Infrastructure provisioning completed successfully!"
      display_provisioned_resources(result[:output])
    else
      puts "❌ Infrastructure provisioning failed: #{result[:error]}"
    end
    
    result
  end

  # Check if infrastructure is already provisioned
  # @return [Hash] Status check result
  def check_infrastructure_status
    puts "🔍 Checking infrastructure status..."
    
    status = {
      s3_bucket: check_s3_bucket,
      lambda_function: check_lambda_function,
      iam_role: check_iam_role,
      iam_policy: check_iam_policy
    }
    
    all_provisioned = status.values.all? { |s| s[:exists] }
    
    if all_provisioned
      puts "✅ All infrastructure components are provisioned"
    else
      puts "⚠️  Some infrastructure components are missing:"
      status.each do |component, info|
        unless info[:exists]
          puts "  ❌ #{component}: #{info[:error]}"
        end
      end
    end
    
    {
      success: all_provisioned,
      status: status
    }
  end

  # Test infrastructure connectivity
  # @return [Hash] Test results
  def test_infrastructure
    puts "🧪 Testing infrastructure connectivity..."
    
    tests = {
      s3_access: test_s3_access,
      lambda_access: test_lambda_access,
      iam_access: test_iam_access
    }
    
    all_tests_passed = tests.values.all? { |t| t[:success] }
    
    if all_tests_passed
      puts "✅ All infrastructure tests passed"
    else
      puts "❌ Some infrastructure tests failed:"
      tests.each do |test_name, result|
        unless result[:success]
          puts "  ❌ #{test_name}: #{result[:error]}"
        end
      end
    end
    
    {
      success: all_tests_passed,
      tests: tests
    }
  end

  # Get infrastructure details
  # @return [Hash] Infrastructure details
  def get_infrastructure_details
    puts "📋 Getting infrastructure details..."
    
    details = {
      s3_bucket: get_s3_bucket_details,
      lambda_function: get_lambda_function_details,
      iam_role: get_iam_role_details,
      environment_variables: get_environment_variables
    }
    
    puts "✅ Infrastructure details retrieved"
    details
  end

  private

  # Validate AWS credentials
  def validate_aws_credentials
    stdout, stderr, status = Open3.capture3('aws sts get-caller-identity')
    
    unless status.success?
      raise "AWS credentials not configured. Please run 'aws configure' first."
    end
    
    identity = JSON.parse(stdout)
    puts "✅ AWS credentials validated for account: #{identity['Account']}"
  end

  # Build environment variables for provisioning
  # @param options [Hash] Provisioning options
  # @return [Hash] Environment variables
  def build_environment_variables(options)
    {
      'AWS_REGION' => options[:region] || Config::AWS_CONFIG[:region],
      'S3_BUCKET' => options[:bucket_name] || Config::AWS_CONFIG[:s3_bucket],
      'LAMBDA_FUNCTION' => options[:lambda_function] || Config::AWS_CONFIG[:lambda_function]
    }
  end

  # Run the provisioning script
  # @param env_vars [Hash] Environment variables
  # @return [Hash] Script execution result
  def run_provisioning_script(env_vars)
    # Make script executable
    File.chmod(0755, @script_path)
    
    # Build environment string
    env_string = env_vars.map { |k, v| "#{k}=#{v}" }.join(' ')
    
    # Run script
    command = "#{env_string} #{@script_path}"
    stdout, stderr, status = Open3.capture3(command)
    
    if status.success?
      {
        success: true,
        output: stdout,
        error: stderr
      }
    else
      {
        success: false,
        output: stdout,
        error: stderr
      }
    end
  end

  # Check S3 bucket status
  # @return [Hash] S3 bucket status
  def check_s3_bucket
    bucket_name = Config::AWS_CONFIG[:s3_bucket]
    
    stdout, stderr, status = Open3.capture3("aws s3api head-bucket --bucket #{bucket_name}")
    
    if status.success?
      { exists: true, name: bucket_name }
    else
      { exists: false, error: stderr.strip, name: bucket_name }
    end
  end

  # Check Lambda function status
  # @return [Hash] Lambda function status
  def check_lambda_function
    function_name = Config::AWS_CONFIG[:lambda_function]
    
    stdout, stderr, status = Open3.capture3("aws lambda get-function --function-name #{function_name}")
    
    if status.success?
      { exists: true, name: function_name }
    else
      { exists: false, error: stderr.strip, name: function_name }
    end
  end

  # Check IAM role status
  # @return [Hash] IAM role status
  def check_iam_role
    role_name = "burns-video-generator-role"
    
    stdout, stderr, status = Open3.capture3("aws iam get-role --role-name #{role_name}")
    
    if status.success?
      { exists: true, name: role_name }
    else
      { exists: false, error: stderr.strip, name: role_name }
    end
  end

  # Check IAM policy status
  # @return [Hash] IAM policy status
  def check_iam_policy
    policy_name = "burns-video-generator-policy"
    
    stdout, stderr, status = Open3.capture3("aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/#{policy_name}")
    
    if status.success?
      { exists: true, name: policy_name }
    else
      { exists: false, error: stderr.strip, name: policy_name }
    end
  end

  # Test S3 access
  # @return [Hash] S3 access test result
  def test_s3_access
    bucket_name = Config::AWS_CONFIG[:s3_bucket]
    
    stdout, stderr, status = Open3.capture3("aws s3 ls s3://#{bucket_name}")
    
    if status.success?
      { success: true }
    else
      { success: false, error: stderr.strip }
    end
  end

  # Test Lambda access
  # @return [Hash] Lambda access test result
  def test_lambda_access
    function_name = Config::AWS_CONFIG[:lambda_function]
    
    stdout, stderr, status = Open3.capture3("aws lambda list-functions --query 'Functions[?FunctionName==`#{function_name}`]'")
    
    if status.success?
      { success: true }
    else
      { success: false, error: stderr.strip }
    end
  end

  # Test IAM access
  # @return [Hash] IAM access test result
  def test_iam_access
    stdout, stderr, status = Open3.capture3("aws iam list-roles --query 'Roles[?RoleName==`burns-video-generator-role`]'")
    
    if status.success?
      { success: true }
    else
      { success: false, error: stderr.strip }
    end
  end

  # Get S3 bucket details
  # @return [Hash] S3 bucket details
  def get_s3_bucket_details
    bucket_name = Config::AWS_CONFIG[:s3_bucket]
    
    stdout, stderr, status = Open3.capture3("aws s3api get-bucket-location --bucket #{bucket_name}")
    
    if status.success?
      location = JSON.parse(stdout)['LocationConstraint']
      {
        name: bucket_name,
        region: location,
        url: "s3://#{bucket_name}"
      }
    else
      { error: stderr.strip }
    end
  end

  # Get Lambda function details
  # @return [Hash] Lambda function details
  def get_lambda_function_details
    function_name = Config::AWS_CONFIG[:lambda_function]
    
    stdout, stderr, status = Open3.capture3("aws lambda get-function --function-name #{function_name}")
    
    if status.success?
      function_info = JSON.parse(stdout)['Configuration']
      {
        name: function_name,
        runtime: function_info['Runtime'],
        timeout: function_info['Timeout'],
        memory_size: function_info['MemorySize'],
        arn: function_info['FunctionArn']
      }
    else
      { error: stderr.strip }
    end
  end

  # Get IAM role details
  # @return [Hash] IAM role details
  def get_iam_role_details
    role_name = "burns-video-generator-role"
    
    stdout, stderr, status = Open3.capture3("aws iam get-role --role-name #{role_name}")
    
    if status.success?
      role_info = JSON.parse(stdout)['Role']
      {
        name: role_name,
        arn: role_info['Arn'],
        created: role_info['CreateDate']
      }
    else
      { error: stderr.strip }
    end
  end

  # Get environment variables for the application
  # @return [Hash] Environment variables
  def get_environment_variables
    {
      'AWS_REGION' => Config::AWS_CONFIG[:region],
      'S3_BUCKET' => Config::AWS_CONFIG[:s3_bucket],
      'LAMBDA_FUNCTION' => Config::AWS_CONFIG[:lambda_function],
      'AWS_ACCESS_KEY_ID' => Config::AWS_CONFIG[:access_key_id] ? '***' : 'Not set',
      'AWS_SECRET_ACCESS_KEY' => Config::AWS_CONFIG[:secret_access_key] ? '***' : 'Not set'
    }
  end

  # Display provisioned resources
  # @param output [String] Script output
  def display_provisioned_resources(output)
    puts "\n📋 Provisioned Resources:"
    puts "  🪣 S3 Bucket: #{Config::AWS_CONFIG[:s3_bucket]}"
    puts "  ⚡ Lambda Function: #{Config::AWS_CONFIG[:lambda_function]}"
    puts "  👤 IAM Role: burns-video-generator-role"
    puts "  📜 IAM Policy: burns-video-generator-policy"
    puts "  📊 CloudWatch Log Group: /aws/lambda/#{Config::AWS_CONFIG[:lambda_function]}"
  end
end 