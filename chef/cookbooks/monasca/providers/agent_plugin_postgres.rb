#
# Copyright 2017 SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "json"
require "yaml"

action :create do
  # initialize the data structure if not available
  node[:monasca] ||= {}
  node[:monasca][:agent_plugin_config] ||= {}
  node[:monasca][:agent_plugin_config][:postgres_instances] ||= {}

  # add the hash with the given values
  node[:monasca][:agent_plugin_config][:postgres_instances][new_resource.built_by] =
    { "built_by" => new_resource.built_by,
      "host" => new_resource.host,
      "username" => new_resource.username,
      "password" => new_resource.password,
      "dbname" => new_resource.dbname,
      "port" => new_resource.port }

  postgres_instances = node[:monasca][:agent_plugin_config][:postgres_instances]

  # be sure the package is installed. that way "/etc/monasca/agent/conf.d/" is available
  # and also the user and group are there
  package "openstack-monasca-agent"

  # NOTE(toabctl): convert/parse first to/from json. Otherwise we have unwanted markers
  # like "- !ruby/hash:Mash" in the yaml output
  postgres_conf = JSON.parse({ "init_config" => nil,
                               "instances" => postgres_instances.values }.to_json).to_yaml

  # write postgres plugin config
  file "/etc/monasca/agent/conf.d/postgres.yaml" do
    content postgres_conf
    owner node[:monasca][:agent][:user]
    group node[:monasca][:agent][:group]
    mode "0640"
    notifies :restart, resources(service: node[:monasca][:agent][:agent_service_name]), :delayed
  end
end
