import '../domain/parent_ai_models.dart';

const parentAIPrivacyBoundary =
    'Parent AI may use only family-visible records for linked children and the active family account. It must not retrieve other families, staff private notes, confidential safeguarding records, internal employment metrics or restricted health data.';

const parentAIDecisionBoundary =
    'Parent AI is advisory. It must not diagnose a child, rank siblings, score parenting quality, infer household circumstances, decide safeguarding outcomes, or make financial, academic or disciplinary decisions.';

const parentDefaultAI = ParentAISnapshot(
  familyAccountId: 'FAM-BGA-0042',
  assistantName: 'Family Intelligence Assistant',
  description:
      'Designed for attendance, learning updates, payments, messages, events and school-life questions. It explains what the cached family-visible records show, what they do not show, and when the school should be contacted.',
  defaultPrompt: 'How is Maryam doing this term?',
  defaultAnswer:
      'Maryam is currently in JSS 2A with 96% attendance and an academic average around 86%. Her recent Mathematics assessment is 88%, and she is active in Chess Club and Debate. The family account shows a ₦40,000 current-term balance in the Parent AI website example. This summary does not include teacher private notes or internal school records.',
  suggestions: [
    ParentAISuggestion(
      prompt: 'How is Maryam doing this term?',
      answer:
          'Maryam is currently in JSS 2A with 96% attendance and an academic average around 86%. Her recent Mathematics assessment is 88%, and she is active in Chess Club and Debate. The family account shows a ₦40,000 current-term balance in the Parent AI website example. This summary does not include teacher private notes or internal school records.',
    ),
    ParentAISuggestion(
      prompt: "Why has Hafsa's attendance dropped?",
      answer:
          'The family-visible attendance records show Hafsa at 92% attendance on the Attendance page, with 23 of 25 school days present and 2 late arrivals. The portal does not know or infer why an attendance pattern changed. If you need the reason behind a late or missed day, contact the school.',
    ),
    ParentAISuggestion(
      prompt: 'What payments are due this month?',
      answer:
          'The current family finance records show Maryam with a ₦30,000 scheduled payment for 25 Sep 2026 through an automatic bank mandate, and Hafsa with a ₦20,000 expected manual partial payment for 20 Sep 2026. These are finance records only and do not affect learning support or grades.',
    ),
    ParentAISuggestion(
      prompt: 'What school events are coming up?',
      answer:
          'Family-visible school-life records list an Inter-house sports briefing on 18 Sep, a Primary family reading afternoon on 24 Sep, and the start of the mid-term break on 03 Oct. Official notices remain the source for instructions or changes.',
    ),
    ParentAISuggestion(
      prompt: 'Summarize messages I may have missed',
      answer:
          'The family messages view shows an unread conversation from Mrs. Amina Yusuf about Maryam completing the Mathematics assessment well. Other visible recent conversations include Hafsa’s reading practice update and a Finance Office receipt notice. Open Messages for the full authorized conversation history.',
    ),
  ],
  privacyBoundary: parentAIPrivacyBoundary,
  decisionBoundary: parentAIDecisionBoundary,
);
