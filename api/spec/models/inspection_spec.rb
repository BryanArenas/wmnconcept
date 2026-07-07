require "rails_helper"

# The §6 state machine is the shared contract and the spine of the app
# (CLAUDE.md — review hardest). These specs pin every transition, guard, side
# effect, and — above all — the invariant that approval never auto-delivers
# without a PDF.
RSpec.describe Inspection, type: :model do
  let(:org) { create(:organization) }
  let(:inspector) { create(:user, :inspector, organization: org) }
  let(:coordinator) { create(:user, :coordinator, organization: org) }
  let(:manager) { create(:user, :manager, organization: org) }

  def inspection(*traits)
    create(:inspection, *traits, organization: org)
  end

  describe "initial state" do
    it "starts unassigned" do
      expect(inspection).to be_unassigned
    end
  end

  describe "assign (unassigned → assigned)" do
    it "sets the inspector and logs a timeline event naming them" do
      insp = inspection
      expect { insp.assign_to!(inspector, actor: coordinator) }
        .to change(insp, :status).from("unassigned").to("assigned")
      expect(insp.assigned_inspector).to eq(inspector)

      event = insp.inspection_events.chronological.last
      expect(event).to have_attributes(
        kind: "assigned",
        message: "Assigned to #{inspector.name}",
        from_status: "unassigned",
        to_status: "assigned",
        actor_type: "User",
        actor_id: coordinator.id,
        actor_label: coordinator.name
      )
    end

    it "refuses to assign with no inspector (guard)" do
      insp = inspection
      expect { insp.assign! }.to raise_error(AASM::InvalidTransition)
      expect(insp.reload).to be_unassigned
    end
  end

  describe "schedule (assigned → scheduled)" do
    it "records the time and enqueues the T-24h reminder" do
      insp = inspection(:assigned)
      time = 3.days.from_now

      expect { insp.schedule_for!(time, actor: coordinator) }
        .to have_enqueued_job(InspectionReminderJob)
      expect(insp).to be_scheduled
      expect(insp.scheduled_at).to be_within(1.second).of(time)
      expect(insp.inspection_events.chronological.last.kind).to eq("scheduled")
    end

    it "refuses to schedule with no datetime (guard)" do
      insp = inspection(:assigned)
      expect { insp.schedule! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "start (scheduled → in_progress)" do
    it "stamps started_at and logs the event" do
      insp = inspection(:scheduled)
      expect { insp.start_by!(actor: inspector) }
        .to change(insp, :status).to("in_progress")
      expect(insp.started_at).to be_present
      expect(insp.inspection_events.chronological.last.kind).to eq("started")
    end
  end

  describe "submit (in_progress → submitted_for_review)" do
    it "is blocked until evidence is complete (ready_for_review? guard)" do
      insp = inspection(:in_progress)
      # ready_for_review? is false until M5 wires photos/form checks.
      expect { insp.submit! }.to raise_error(AASM::InvalidTransition)
      expect(insp.reload).to be_in_progress
    end

    it "moves to review once evidence is complete" do
      insp = inspection(:in_progress)
      allow(insp).to receive(:ready_for_review?).and_return(true)

      expect { insp.submit_by!(actor: inspector) }
        .to change(insp, :status).to("submitted_for_review")
      expect(insp.submitted_at).to be_present
      expect(insp.inspection_events.chronological.last.kind).to eq("submitted")
    end
  end

  describe "approve (submitted_for_review → approved)" do
    it "holds at approved and NEVER auto-delivers without a PDF (the §6 invariant)" do
      insp = inspection(:submitted_for_review)

      expect { insp.approve_by!(actor: manager) }
        .to have_enqueued_job(GenerateReportPdfJob).with(insp)

      expect(insp).to be_approved
      expect(insp).not_to be_delivered
      expect(insp.approved_at).to be_present
    end

    it "does not create the invoice at approval (that waits for delivery)" do
      insp = inspection(:submitted_for_review)
      expect { insp.approve_by!(actor: manager) }
        .not_to have_enqueued_job(CreateInvoiceJob)
    end
  end

  describe "deliver (approved → delivered)" do
    it "is the only path to delivered and fires invoicing" do
      insp = inspection(:approved)

      expect { insp.deliver! }
        .to have_enqueued_job(CreateInvoiceJob).with(insp)
      expect(insp).to be_delivered
      expect(insp.delivered_at).to be_present
      expect(insp.inspection_events.chronological.last.kind).to eq("delivered")
    end
  end

  describe "reject (submitted_for_review → in_progress, rework loop)" do
    it "bounces back to in_progress and stores the note" do
      insp = inspection(:submitted_for_review)

      expect { insp.reject_with_note!("Roof-to-wall photos are blurry", actor: manager) }
        .to change(insp, :status).from("submitted_for_review").to("in_progress")
      expect(insp.rejection_note).to eq("Roof-to-wall photos are blurry")

      event = insp.inspection_events.chronological.last
      expect(event.kind).to eq("rejected")
      expect(event.message).to eq("Rejected — Roof-to-wall photos are blurry")
    end

    it "refuses to reject with no note (guard)" do
      insp = inspection(:submitted_for_review)
      expect { insp.reject! }.to raise_error(AASM::InvalidTransition)
      expect(insp.reload).to be_submitted_for_review
    end
  end

  describe "cancel (any pre-delivered → cancelled)" do
    [nil, :assigned, :scheduled, :in_progress, :submitted_for_review, :approved].each do |trait|
      it "cancels from #{trait || 'unassigned'}" do
        insp = trait ? inspection(trait) : inspection
        expect { insp.cancel_by!(actor: coordinator) }
          .to change(insp, :status).to("cancelled")
        expect(insp.cancelled_at).to be_present
      end
    end

    it "cannot cancel a delivered inspection" do
      insp = inspection(:delivered)
      expect { insp.cancel! }.to raise_error(AASM::InvalidTransition)
      expect(insp.reload).to be_delivered
    end
  end

  describe "illegal transitions" do
    it "rejects skipping ahead from unassigned" do
      insp = inspection
      expect { insp.approve! }.to raise_error(AASM::InvalidTransition)
      expect { insp.start! }.to raise_error(AASM::InvalidTransition)
      expect { insp.deliver! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "the full happy path" do
    it "walks unassigned → delivered, one timeline entry per step, in order" do
      insp = inspection
      insp.assign_to!(inspector, actor: coordinator)
      insp.schedule_for!(2.days.from_now, actor: coordinator)
      insp.start_by!(actor: inspector)
      allow(insp).to receive(:ready_for_review?).and_return(true)
      insp.submit_by!(actor: inspector)
      insp.approve_by!(actor: manager)
      insp.deliver! # stands in for the report pipeline

      expect(insp).to be_delivered
      expect(insp.inspection_events.chronological.pluck(:kind))
        .to eq(%w[assigned scheduled started submitted approved delivered])
    end
  end
end
