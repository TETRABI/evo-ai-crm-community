class PipelineTaskMailer < ApplicationMailer
  def task_assigned(task)
    @task = task
    @assignee = task.assigned_to
    @pipeline_item = task.pipeline_item
    @account = task.account
    @conversation = task.conversation
    @contact = task.contact

    return if @assignee.blank?

    subject = I18n.t('pipeline_task_mailer.task_assigned.subject',
                     account_name: @account.name,
                     task_title: @task.title)

    mail(to: @assignee.email, subject: subject)
  end

  def task_due_soon(task)
    @task = task
    @assignee = task.assigned_to
    @pipeline_item = task.pipeline_item
    @account = task.account
    @conversation = task.conversation
    @contact = task.contact

    return if @assignee.blank?

    subject = I18n.t('pipeline_task_mailer.task_due_soon.subject',
                     account_name: @account.name,
                     task_title: @task.title)

    mail(to: @assignee.email, subject: subject)
  end

  def task_overdue(task)
    @task = task
    @assignee = task.assigned_to
    @pipeline_item = task.pipeline_item
    @account = task.account
    @conversation = task.conversation
    @contact = task.contact

    return if @assignee.blank?

    subject = I18n.t('pipeline_task_mailer.task_overdue.subject',
                     account_name: @account.name,
                     task_title: @task.title)

    mail(to: @assignee.email, subject: subject)
  end
end
