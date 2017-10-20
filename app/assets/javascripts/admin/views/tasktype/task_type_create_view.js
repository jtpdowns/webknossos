// @flow
import React from "react";
import { Form, Checkbox, Input, Select, Card, Button } from "antd";
import app from "app";
import { getTeams, createTaskType, updateTaskType } from "admin/admin_rest_api";
import type { APITeamType, APITaskTypeType } from "admin/api_flow_types";

const FormItem = Form.Item;
const Option = Select.Option;

type Props = {
  taskTypeId: ?string,
  form: Object,
};

type State = {
  teams: Array<APITeamType>,
};

class TaskTypeCreateView extends React.PureComponent<Props, State> {
  state = {
    teams: [],
  };

  componentDidMount() {
    this.fetchData();

    const defaultValues = {
      settings: {
        somaClickingAllowed: true,
        branchPointsAllowed: true,
        advancedOptionsAllowed: true,
      },
    };
    this.props.form.setFieldsValue(defaultValues);
  }

  async fetchData() {
    this.setState({ teams: await getTeams() });
  }

  handleSubmit = e => {
    e.preventDefault();
    this.props.form.validateFields((err, formValues) => {
      if (!err) {
        if (this.props.taskTypeId) {
          updateTaskType(this.props.taskTypeId, formValues);
        } else {
          createTaskType(formValues);
        }

        app.router.navigate("/taskTypes", { trigger: true });
      }
    });
  };

  render() {
    const { getFieldDecorator } = this.props.form;
    const titlePrefix = this.props.taskTypeId ? "Update " : "Create";

    return (
      <div className="container wide task-types-administration">
        <Card title={<h3>{titlePrefix} Task Type</h3>}>
          <Form onSubmit={this.handleSubmit} layout="vertical">
            <FormItem label="Summary" hasFeedback>
              {getFieldDecorator("summary", {
                rules: [
                  {
                    required: true,
                  },
                  { min: 3 },
                ],
              })(<Input />)}
            </FormItem>

            <FormItem label="Team" hasFeedback>
              {getFieldDecorator("team", {
                rules: [
                  {
                    required: true,
                  },
                ],
              })(
                <Select
                  allowClear
                  showSearch
                  placeholder="Select a Team"
                  optionFilterProp="children"
                  style={{ width: "100%" }}
                >
                  {this.state.teams.map((team: APITeamType) => (
                    <Option key={team.id} value={team.name}>
                      {`${team.name}`}
                    </Option>
                  ))}
                </Select>,
              )}
            </FormItem>

            <FormItem
              label={
                <span>
                  Description (
                  <a
                    href="https://markdown-it.github.io/"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Markdown enabled
                  </a>
                  )
                </span>
              }
              hasFeedback
            >
              {getFieldDecorator("description", {
                rules: [
                  {
                    required: true,
                  },
                ],
              })(<Input />)}
            </FormItem>

            <FormItem label="Allowed Modes" hasFeedback>
              {getFieldDecorator("settings.allowedModes", {
                rules: [
                  {
                    required: true,
                  },
                ],
              })(
                <Select
                  mode="multiple"
                  allowClear
                  placeholder="Select all Allowed Modes"
                  optionFilterProp="children"
                  style={{ width: "100%" }}
                >
                  <Option value="orthogonal">Orthogonal</Option>
                  <Option value="oblique">Oblique</Option>
                  <Option value="flight">Flight</Option>
                </Select>,
              )}
            </FormItem>

            <FormItem label="Settings">
              {getFieldDecorator("settings.somaClickingAllowed", {
                valuePropName: "checked",
              })(<Checkbox>Allow Soma clicking</Checkbox>)}
            </FormItem>

            <FormItem>
              {getFieldDecorator("settings.branchPointsAllowed", {
                valuePropName: "checked",
              })(<Checkbox>Allow Branchpoints</Checkbox>)}
            </FormItem>
            <FormItem>
              {getFieldDecorator("settings.advancedOptionsAllowed", {
                valuePropName: "checked",
              })(<Checkbox> Advanced Tracing Options</Checkbox>)}
            </FormItem>

            <FormItem label="Preferred Mode" hasFeedback>
              {getFieldDecorator("settings.preferredMode", {
                rules: [
                  {
                    required: true,
                  },
                ],
              })(
                <Select allowClear optionFilterProp="children" style={{ width: "100%" }}>
                  <Option value={null}>Any</Option>
                  <Option value="orthogonal">Orthogonal</Option>
                  <Option value="oblique">Oblique</Option>
                  <Option value="flight">Flight</Option>
                </Select>,
              )}
            </FormItem>

            <FormItem>
              <Button type="primary" htmlType="submit">
                {titlePrefix} Task Type
              </Button>
            </FormItem>
          </Form>
        </Card>
      </div>
    );
  }
}

export default Form.create()(TaskTypeCreateView);
