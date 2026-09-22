const teacherAssessmentSaveBoundary =
    'Saving score-entry progress writes an auditable local draft and queues synchronization. It does not lock marks, release results or confirm server receipt.';

const teacherAssessmentSubmissionBoundary =
    'Submitting scores means submitted for review or locking according to school policy. A teacher device cannot self-lock, release or make results parent-visible without authoritative school workflow acknowledgement.';

const teacherAssessmentAiBoundary =
    'Teacher AI may summarize class-level patterns, suggest revision activities and draft feedback, but it cannot create, alter, round, normalize or release student marks. The teacher remains responsible for every entered score.';
