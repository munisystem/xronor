require "spec_helper"

module Xronor
  module AWS
    describe CloudWatchEvents do
      let(:client) do
        Aws::CloudWatchEvents::Client.new(stub_responses: true)
      end

      let(:cwe) do
        described_class.new(client: client)
      end

      describe "#deregister_job" do
        let(:job_name) do
          "scheduler-production-create_new_companies"
        end

        let(:targets) do
          [
            {
              id: "6e70e716-1e14-465b-85ad-12744aedefb7",
              arn: "arn:aws:lambda:ap-northeast-1:012345678901:function:scheduler-production-create_new_companies",
            }
          ]
        end

        before do
          client.stub_responses(:list_targets_by_rule, targets: targets)
        end

        it "should delete rule and targets" do
          expect(client).to receive(:remove_targets).with({
            rule: "scheduler-production-create_new_companies",
            ids: ["6e70e716-1e14-465b-85ad-12744aedefb7"],
          })
          expect(client).to receive(:delete_rule).with({
            name: "scheduler-production-create_new_companies",
          })

          cwe.deregister_job(job_name)
        end
      end

      describe "#list_jobs" do
        let(:rules) do
          [
            {
              name: "scheduler-production-create_new_companies",
              arn: "arn:aws:events:ap-northeast-1:012345678901:rule/scheduler-production-create_new_companies",
              state: "ENABLED",
              description: "",
              schedule_expression: "cron(30 0 * * ? *)",
            },
            {
              name: "scheduler-qa-create_new_companies",
              arn: "arn:aws:events:ap-northeast-1:012345678901:rule/scheduler-qa-create_new_companies",
              state: "ENABLED",
              description: "",
              schedule_expression: "cron(0 * * * ? *)",
            },
            {
              name: "CheckEC2ScheduledEvents",
              arn: "arn:aws:events:ap-northeast-1:012345678901:rule/CheckEC2ScheduledEvents",
              state: "ENABLED",
              description: "Check EC2 Scheduled Events at 09:30 JST",
              schedule_expression: "cron(30 0 * * ? *)",
            },
          ]
        end

        before do
          client.stub_responses(:list_rules, rules: rules)
        end

        context "when no prefix is given" do
          it "should return all rules" do
            expect(cwe.list_jobs).to eq([
              "scheduler-production-create_new_companies",
              "scheduler-qa-create_new_companies",
              "CheckEC2ScheduledEvents",
            ])
          end
        end

        context "when prefix is given" do
          let(:prefix) do
            "scheduler-"
          end

          it "should return all rules" do
            expect(cwe.list_jobs(prefix)).to eq([
              "scheduler-production-create_new_companies",
              "scheduler-qa-create_new_companies",
            ])
          end
        end
      end

      describe "#register_job" do
        let(:job) do
          double("job",
            name: "production-create_new_companies",
            description: "Create new companies",
            schedule: "10 0 * * *",
            command: "/bin/bash -l -c 'bundle exec rake create_new_companies RAILS_ENV=production'",
          )
        end

        let(:prefix) do
          "scheduler-"
        end

        let(:cluster) do
          "scheduler"
        end

        let(:task_definition) do
          "scheduler-app"
        end

        let(:container) do
          "scheduler-app"
        end

        let(:target_function_arn) do
          "arn:aws:lambda:ap-northeast-1:012345678901:function:schedule-app"
        end

        let(:rule_arn) do
          "arn:aws:events:ap-northeast-1:012345678901:rule/scheduler-production-create_new_companies"
        end

        before do
          client.stub_responses(:put_rule, rule_arn: rule_arn)
          client.stub_responses(:put_targets, failed_entry_count: 0, failed_entries: [])

          allow(job).to receive(:cloud_watch_rule_name).with(prefix).and_return("scheduler-production-create_new_companies-7a7c4f3e190d7")
          allow(job).to receive(:cloud_watch_schedule).and_return("cron(10 0 * * ? *)")
          allow(client).to receive(:put_rule).with({
            name: "scheduler-production-create_new_companies-7a7c4f3e190d7",
            description: "Create new companies",
            schedule_expression: "cron(10 0 * * ? *)",
          }).and_return(double("response", rule_arn: "arn:aws:events:ap-northeast-1:012345678901:rule/scheduler-production-create_new_companies"))
          allow(client).to receive(:put_targets).with({
            rule: "scheduler-production-create_new_companies-7a7c4f3e190d7",
            targets: [
              {
                id: "id",
                arn: "arn:aws:lambda:ap-northeast-1:012345678901:function:schedule-app",
                input_transformer: {
                  input_paths_map: {
                    "resources" => "$.resources",
                    "time" => "$.time",
                  },
                  input_template: %q({"resources":<resources>,"time":<time>,"cluster":"scheduler","task_definition":"scheduler-app","container":"scheduler-app","command":["/bin/bash","-l","-c","bundle exec rake create_new_companies RAILS_ENV=production"]}),
                },
              },
            ],
          })
          allow(cwe).to receive(:generate_id).and_return("id")
        end

        it "should return rule ARN" do
          expect(cwe.register_job(job, prefix, cluster, task_definition, container, target_function_arn)).to eq "arn:aws:events:ap-northeast-1:012345678901:rule/scheduler-production-create_new_companies"
        end
      end
    end
  end
end
