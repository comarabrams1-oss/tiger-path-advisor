import '../models/course.dart';

const List<Course> computerScienceCourseCatalog = [
  Course(
    code: 'CSC 132',
    title: 'Introduction to Computing and Programming Logic',
    credits: 3,
    category: 'Major',
  ),

  Course(
    code: 'CSC 133',
    title: 'Digital Logic',
    credits: 3,
    category: 'Major',
  ),

  Course(
    code: 'CSC 135',
    title: 'Introduction to Programming',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 132'],
    ],
  ),

  Course(
    code: 'CSC 138',
    title: 'Object Oriented Programming',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 135'],
    ],
  ),

  Course(
    code: 'CSC 139',
    title: 'Web Development',
    credits: 3,
    category: 'Major',
  ),

  Course(
    code: 'CSC 232',
    title: 'Foundations of App Development',
    credits: 3,
    category: 'Major',
  ),

  Course(
    code: 'CSC 233',
    title: 'Data Structures & Algorithms I',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 135'],
    ],
  ),

  Course(
    code: 'CSC 234',
    title: 'Theory of Computations',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 132'],
    ],
    allowsInstructorPermission: true,
  ),

  Course(
    code: 'CSC 235',
    title: 'Fundamentals of App Development',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 232'],
    ],
  ),

  Course(
    code: 'CSC 237',
    title: 'Java Programming',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 135'],
    ],
    allowsInstructorPermission: true,
  ),

  Course(
    code: 'CSC 238',
    title: 'Introduction to Computer Security',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 135'],
    ],
  ),

  Course(
    code: 'CSC 334',
    title: 'Data Structures and Algorithms II',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 233'],
    ],
  ),

  Course(
    code: 'CSC 336',
    title: 'Advanced Concepts in App Development',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 235'],
    ],
  ),

  Course(
    code: 'CSC 337',
    title: 'Computer Organization and Architecture',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 133', 'CE 231'],
    ],
  ),

  Course(
    code: 'CSC 338',
    title: 'Introduction to Artificial Intelligence',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 233'],
      ['MATH 336'],
    ],
  ),

  Course(
    code: 'CSC 339',
    title: 'Data Communication and Networking',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 337'],
    ],
  ),

  Course(
    code: 'CSC 430',
    title: 'Senior Research and Professional Experience',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 334'],
    ],
    minimumClassStanding: 'Senior',
  ),

  Course(
    code: 'CSC 431',
    title: 'Programming Languages',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 334'],
    ],
    allowsInstructorPermission: true,
  ),

  Course(
    code: 'CSC 434',
    title: 'Database Management',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['MATH 336'],
    ],
    allowsInstructorPermission: true,
  ),

  Course(
    code: 'CSC 435',
    title: 'Software Engineering Principles',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 233'],
    ],
  ),

  Course(
    code: 'CSC 436',
    title: 'Operating Systems',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 233'],
      ['CSC 337'],
    ],
  ),

  Course(
    code: 'CSC 437',
    title: 'Senior Capstone',
    credits: 3,
    category: 'Major',
    prerequisiteGroups: [
      ['CSC 334'],
      ['CSC 336'],
      ['CSC 435'],
    ],
  ),
];