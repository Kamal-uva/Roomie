// Pure logic shared by the dashboard and regression tests.
export function nextVacuumMember(members, lastVacuum) {
  if (!members.length) return null;
  if (!lastVacuum) return members[0];
  const index = members.findIndex(m => m.user_id === lastVacuum.member_id);
  // If the last person is no longer a roommate, restart at the first member.
  return members[index < 0 ? 0 : (index + 1) % members.length];
}
