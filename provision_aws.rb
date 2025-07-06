#!/usr/bin/env ruby

require_relative 'lib/services/aws_provisioner'
require_relative 'config/services'

puts "🚀 AWS Infrastructure Provisioning"
puts "=================================="

begin
  # Initialize the provisioner
  provisioner = AWSProvisioner.new
  
  # Check current status
  puts "\n🔍 Checking current infrastructure status..."
  status = provisioner.check_infrastructure_status
  
  if status[:success]
    puts "✅ All infrastructure is already provisioned!"
    
    # Test connectivity
    puts "\n🧪 Testing connectivity..."
    test_result = provisioner.test_infrastructure
    
    if test_result[:success]
      puts "✅ All connectivity tests passed!"
      
      # Show details
      puts "\n📋 Infrastructure Details:"
      details = provisioner.get_infrastructure_details
      
      details.each do |component, info|
        if info.is_a?(Hash) && !info[:error]
          puts "  ✅ #{component}:"
          info.each do |key, value|
            puts "    #{key}: #{value}"
          end
        end
      end
      
      puts "\n🎉 Your AWS infrastructure is ready for the Burns video pipeline!"
      
    else
      puts "❌ Some connectivity tests failed. Please check your AWS configuration."
    end
    
  else
    puts "⚠️  Some infrastructure components are missing."
    puts "\nWould you like to provision the missing components? (y/n)"
    response = gets.chomp.downcase
    
    if response == 'y'
      puts "\n🚀 Provisioning infrastructure..."
      
      # Provision with default options
      result = provisioner.provision_infrastructure({
        region: Config::AWS_CONFIG[:region],
        bucket_name: Config::AWS_CONFIG[:s3_bucket],
        lambda_function: Config::AWS_CONFIG[:lambda_function]
      })
      
      if result[:success]
        puts "\n✅ Infrastructure provisioning completed successfully!"
        puts "\n📋 Provisioned Resources:"
        puts "  🪣 S3 Bucket: #{Config::AWS_CONFIG[:s3_bucket]}"
        puts "  ⚡ Lambda Function: #{Config::AWS_CONFIG[:lambda_function]}"
        puts "  👤 IAM Role: burns-video-generator-role"
        puts "  📜 IAM Policy: burns-video-generator-policy"
        puts "  📊 CloudWatch Log Group: /aws/lambda/#{Config::AWS_CONFIG[:lambda_function]}"
        
        puts "\n🔧 Next Steps:"
        puts "1. Test S3 service: ruby test_s3_service.rb"
        puts "2. Build Lambda video generation function"
        puts "3. Test the full pipeline"
        
      else
        puts "❌ Infrastructure provisioning failed:"
        puts result[:error]
        exit 1
      end
      
    else
      puts "❌ Infrastructure provisioning cancelled."
      puts "Please run this script again when you're ready to provision."
      exit 1
    end
  end
  
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts "\nTo fix this:"
  puts "1. Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  puts "2. Configure AWS credentials: aws configure"
  puts "3. Set environment variables:"
  puts "   export AWS_ACCESS_KEY_ID='your_key'"
  puts "   export AWS_SECRET_ACCESS_KEY='your_secret'"
  puts "   export AWS_REGION='us-east-1'"
  puts "4. Install AWS SDK: gem install aws-sdk-s3"
end

puts "\n📚 Documentation:"
puts "  • AWS CLI: https://docs.aws.amazon.com/cli/"
puts "  • AWS SDK for Ruby: https://docs.aws.amazon.com/sdk-for-ruby/"
puts "  • S3: https://docs.aws.amazon.com/s3/"
puts "  • Lambda: https://docs.aws.amazon.com/lambda/" 