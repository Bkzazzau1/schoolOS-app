import '../domain/house_models.dart';

const houseWebsiteSeed = <SchoolHouse>[
  SchoolHouse(
    id: 'HOUSE-BLUE',
    name: 'Blue House',
    captain: 'Amina Bello',
    coordinator: 'Mrs. Fatima Bello',
    members: 172,
    points: 428,
    sports: 170,
    academicCompetitions: 138,
    service: 120,
    status: 'Leading',
  ),
  SchoolHouse(
    id: 'HOUSE-RED',
    name: 'Red House',
    captain: 'David Terna',
    coordinator: 'Mr. Daniel John',
    members: 168,
    points: 401,
    sports: 150,
    academicCompetitions: 141,
    service: 110,
    status: 'Strong',
  ),
  SchoolHouse(
    id: 'HOUSE-GREEN',
    name: 'Green House',
    captain: 'Hauwa Musa',
    coordinator: 'Mrs. Grace Audu',
    members: 174,
    points: 389,
    sports: 142,
    academicCompetitions: 132,
    service: 115,
    status: 'Strong',
  ),
  SchoolHouse(
    id: 'HOUSE-GOLD',
    name: 'Gold House',
    captain: 'Samuel Okafor',
    coordinator: 'Mr. Peter James',
    members: 169,
    points: 371,
    sports: 135,
    academicCompetitions: 129,
    service: 107,
    status: 'On track',
  ),
];

const houseKpis = <HouseKpi>[
  HouseKpi('Active houses', '4', 'Whole-school structure'),
  HouseKpi('Members', '683', 'Mock total across houses'),
  HouseKpi('Events this term', '12', 'Sports, quiz, service'),
  HouseKpi('Leading house', 'Blue', '428 points'),
  HouseKpi('Ranking scope', 'House only', 'No academic rank conversion'),
];

const houseScopeTitle = 'Houses & Teams';
const houseScopeSubtitle = 'Belonging, competition and service';
const houseScopeDescription =
    'Configure school houses, teams, captains, coordinators, points and activities without mixing house points into academic grading.';

const houseStandingsDescription =
    'Points can come from sports, quizzes, conduct-approved service and school competitions.';

const houseAcademicBoundary =
    'House points are for school-life participation and competitions. They must not secretly change exam results, promotion decisions or child academic profiles.';

int get houseMemberTotal =>
    houseWebsiteSeed.fold(0, (total, house) => total + house.members);

SchoolHouse get leadingHouse => houseWebsiteSeed.reduce(
      (current, next) => next.points > current.points ? next : current,
    );
