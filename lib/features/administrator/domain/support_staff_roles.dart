const supportStaffRoles = <String, String>{
  'driver': 'Driver',
  'cleaner': 'Cleaner',
  'security': 'Security Guard',
  'cook': 'Cook / Kitchen Staff',
  'maintenance': 'Maintenance Staff',
  'gardener': 'Gardener',
  'support': 'Other Support Staff',
};

const supportStaffDuties = <String, String>{
  'operations.transport': 'Assigned transport routes and vehicle checks',
  'operations.cleaning': 'Assigned cleaning areas and checklists',
  'operations.security': 'Assigned security duties and incident reports',
  'operations.kitchen': 'Assigned meal preparation and kitchen checks',
  'operations.maintenance': 'Assigned repairs and maintenance checks',
  'operations.grounds': 'Assigned gardening and grounds work',
  'operations.assigned_tasks': 'Own assigned tasks and completion reports',
};

Set<String> supportDutiesForRole(String role) => {
  'operations.assigned_tasks',
  if (role == 'driver') 'operations.transport',
  if (role == 'cleaner') 'operations.cleaning',
  if (role == 'security') 'operations.security',
  if (role == 'cook') 'operations.kitchen',
  if (role == 'maintenance') 'operations.maintenance',
  if (role == 'gardener') 'operations.grounds',
};
