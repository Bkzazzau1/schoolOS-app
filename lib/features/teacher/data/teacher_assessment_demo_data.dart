const teacherAssessmentSaveBoundary =
    'Saving a draft or entering scores writes an auditable local record and queues synchronization. It does not lock marks, release results or confirm server receipt.';

const teacherAssessmentSubmissionBoundary =
    'Submitting scores sends them for review. A Teacher device cannot lock or release results itself - locking and release are a separate, explicit Administrator/Proprietor action with its own audit trail.';

const teacherAssessmentCorrectionBoundary =
    'A correction made after submission, locking or release is never a silent rewrite: it is recorded as an explicit, audited change alongside the previous value.';

const teacherAssessmentAiBoundary =
    'Teacher AI may summarize class-level patterns, suggest revision activities and draft feedback, but it cannot create, alter, round, normalize or release student marks. The teacher remains responsible for every entered score.';
