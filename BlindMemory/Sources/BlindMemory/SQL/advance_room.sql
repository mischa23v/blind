UPDATE room SET currentRevision = :next
WHERE profile = :profile AND id = :room AND currentRevision = :base;
