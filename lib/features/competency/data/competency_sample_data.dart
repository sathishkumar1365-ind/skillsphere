// Placeholder competency library for building the UI before the Spring Boot
// API exists. Employee IDs match OrgData.sample (EMP-1001 … EMP-1036).
//
// No logo links here on purpose: the samples show the lettered badges. HRD
// adds a logo link when creating a competency.

import 'competency_models.dart';

const _hrd = 'Anitha Joseph';

final List<Competency> sampleCompetencies = [
  // ------------------------------------------------------------ Languages
  Competency(
    id: 'CMP-001',
    name: 'Java',
    category: CompetencyCategory.language,
    description: 'Object-oriented, strongly typed language that runs on the JVM. '
        'Our main language for backend services built with Spring Boot.',
    levelDescriptions: const [
      'Has core Java knowledge: syntax, data types, operators, loops and basic OOP.',
      'Aware of data structures and collections, file handling, exceptions and strings.',
      'Writes clean OOP code on their own: generics, streams, lambdas and JUnit tests.',
      'Builds production services: multithreading, JDBC/JPA, design patterns, profiling.',
      'Designs modules and APIs, tunes JVM memory and performance, mentors others.',
      'Sets Java standards for the organisation and solves the hardest JVM problems.',
    ],
    createdAt: DateTime(2026, 1, 12),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1001', 5),
      CompetencyHolder('EMP-1002', 4),
      CompetencyHolder('EMP-1003', 3),
      CompetencyHolder('EMP-1004', 2),
      CompetencyHolder('EMP-1005', 3),
      CompetencyHolder('EMP-1006', 1),
      CompetencyHolder('EMP-1007', 2, verified: false),
      CompetencyHolder('EMP-1008', 3),
      CompetencyHolder('EMP-1009', 3),
      CompetencyHolder('EMP-1011', 2),
      CompetencyHolder('EMP-1012', 4),
      CompetencyHolder('EMP-1013', 2),
      CompetencyHolder('EMP-1014', 2),
      CompetencyHolder('EMP-1015', 1, verified: false),
    ],
  ),
  Competency(
    id: 'CMP-002',
    name: 'Python',
    category: CompetencyCategory.language,
    description: 'General-purpose language used by Data & Analytics for pipelines, '
        'scripting and machine learning.',
    levelDescriptions: const [
      'Knows Python syntax, variables, conditions, loops and functions.',
      'Uses lists, dictionaries, modules, file handling and virtual environments.',
      'Writes reusable modules, handles errors, uses pandas and tests with pytest.',
      'Builds production scripts and pipelines; packages code and speeds up slow parts.',
      'Designs larger Python systems and async code; tunes performance; mentors.',
      'Defines Python standards and tooling for the organisation.',
    ],
    createdAt: DateTime(2026, 1, 12),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1010', 1),
      CompetencyHolder('EMP-1019', 5),
      CompetencyHolder('EMP-1020', 3),
      CompetencyHolder('EMP-1021', 2),
      CompetencyHolder('EMP-1022', 2, verified: false),
      CompetencyHolder('EMP-1023', 4),
      CompetencyHolder('EMP-1028', 1, verified: false),
    ],
  ),
  Competency(
    id: 'CMP-003',
    name: 'Dart',
    category: CompetencyCategory.language,
    description: 'Client-optimised language behind Flutter, used for SkillSphere\'s '
        'own web and mobile apps.',
    levelDescriptions: const [
      'Knows Dart syntax, types, functions and the basics of null safety.',
      'Uses classes, collections, async/await and Futures in small programs.',
      'Writes clean null-safe code with streams, generics and unit tests.',
      'Structures app-sized codebases and packages; reviews others\' Dart code.',
      'Designs app architecture and shared packages; profiles and optimises.',
      'Sets Dart and Flutter coding standards across teams.',
    ],
    createdAt: DateTime(2026, 2, 3),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1002', 3),
      CompetencyHolder('EMP-1004', 4),
      CompetencyHolder('EMP-1008', 3),
      CompetencyHolder('EMP-1011', 3),
      CompetencyHolder('EMP-1033', 1, verified: false),
    ],
  ),
  Competency(
    id: 'CMP-004',
    name: 'SQL',
    category: CompetencyCategory.language,
    description: 'Query language for relational databases. Used every day with '
        'PostgreSQL for application data and reporting.',
    levelDescriptions: const [
      'Writes simple SELECT queries with WHERE and ORDER BY.',
      'Uses JOINs, GROUP BY, aggregates and basic INSERT, UPDATE and DELETE.',
      'Writes subqueries, CTEs and window functions; understands indexes.',
      'Designs normalised schemas, reads query plans and tunes slow queries.',
      'Handles complex migrations, partitioning, locking and scale.',
      'Defines data-modelling standards and solves the hardest database issues.',
    ],
    createdAt: DateTime(2026, 2, 3),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1003', 3),
      CompetencyHolder('EMP-1006', 1),
      CompetencyHolder('EMP-1010', 1, verified: false),
      CompetencyHolder('EMP-1016', 2),
      CompetencyHolder('EMP-1019', 4),
      CompetencyHolder('EMP-1020', 3),
      CompetencyHolder('EMP-1021', 3),
      CompetencyHolder('EMP-1024', 3),
    ],
  ),

  // ---------------------------------------------------------------- Tools
  Competency(
    id: 'CMP-005',
    name: 'Jira',
    category: CompetencyCategory.tool,
    description: 'Work-tracking tool for planning sprints, tracking issues and '
        'reporting delivery progress.',
    levelDescriptions: const [
      'Finds, views and comments on issues.',
      'Creates and updates issues; uses boards and basic filters.',
      'Plans sprints, writes JQL filters and builds simple dashboards.',
      'Configures boards and reports for a team; keeps the backlog healthy.',
      'Administers projects: workflows, schemes, automation rules and permissions.',
      'Designs the Jira setup for the whole organisation and coaches other admins.',
    ],
    createdAt: DateTime(2026, 2, 18),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1001', 4),
      CompetencyHolder('EMP-1002', 3),
      CompetencyHolder('EMP-1013', 4),
      CompetencyHolder('EMP-1014', 2),
      CompetencyHolder('EMP-1015', 4),
      CompetencyHolder('EMP-1025', 3),
      CompetencyHolder('EMP-1030', 2, verified: false),
    ],
  ),
  Competency(
    id: 'CMP-006',
    name: 'Docker',
    category: CompetencyCategory.tool,
    description: 'Container platform used to package and run our services the same '
        'way on laptops, in CI and in the cloud.',
    levelDescriptions: const [
      'Understands what containers and images are.',
      'Runs containers from existing images with the basic docker commands.',
      'Writes Dockerfiles and docker-compose files for local development.',
      'Builds small, secure multi-stage images and debugs container issues.',
      'Optimises build pipelines, registries and image security scanning.',
      'Defines container standards across teams and solves complex runtime issues.',
    ],
    createdAt: DateTime(2026, 3, 4),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1005', 2),
      CompetencyHolder('EMP-1009', 2, verified: false),
      CompetencyHolder('EMP-1025', 5),
      CompetencyHolder('EMP-1026', 4),
      CompetencyHolder('EMP-1028', 3),
      CompetencyHolder('EMP-1029', 2),
    ],
  ),
  Competency(
    id: 'CMP-007',
    name: 'Kubernetes',
    category: CompetencyCategory.tool,
    description: 'Container orchestration platform that runs and scales our '
        'services in the cloud.',
    levelDescriptions: const [
      'Knows the basic ideas: pods, nodes and clusters.',
      'Uses kubectl to look at resources and logs in an existing cluster.',
      'Writes Deployments, Services and ConfigMaps; deploys apps with Helm.',
      'Handles autoscaling, ingress, secrets and production troubleshooting.',
      'Designs cluster setup, networking, security policies and monitoring.',
      'Leads the Kubernetes platform strategy and resolves the worst outages.',
    ],
    createdAt: DateTime(2026, 3, 4),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1025', 5),
      CompetencyHolder('EMP-1026', 2),
      CompetencyHolder('EMP-1028', 4),
    ],
  ),
  Competency(
    id: 'CMP-008',
    name: 'Figma',
    category: CompetencyCategory.tool,
    description: 'Collaborative design tool for wireframes, UI design, prototypes '
        'and design systems.',
    levelDescriptions: const [
      'Opens files, looks through designs and leaves comments.',
      'Creates simple frames, shapes and text; uses existing components.',
      'Builds screens with auto layout and styles; makes clickable prototypes.',
      'Creates reusable components with variants and maintains a team library.',
      'Runs the design system and sets up hand-off with developers.',
      'Sets design-tool standards for the organisation and trains designers.',
    ],
    createdAt: DateTime(2026, 4, 9),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1030', 5),
      CompetencyHolder('EMP-1031', 4),
      CompetencyHolder('EMP-1032', 2),
      CompetencyHolder('EMP-1033', 4),
    ],
  ),
  Competency(
    id: 'CMP-009',
    name: 'Selenium',
    category: CompetencyCategory.tool,
    description: 'Browser automation tool the QA team uses for automated web '
        'UI testing.',
    levelDescriptions: const [
      'Understands what UI test automation is and where Selenium fits.',
      'Edits simple scripts and runs existing test suites.',
      'Writes stable tests with good locators, waits and page objects.',
      'Builds test frameworks with reporting and runs them in CI.',
      'Runs parallel, cross-browser grids and removes flaky tests.',
      'Defines the UI test-automation strategy for the organisation.',
    ],
    createdAt: DateTime(2026, 4, 9),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1013', 5),
      CompetencyHolder('EMP-1014', 3),
      CompetencyHolder('EMP-1015', 3),
      CompetencyHolder('EMP-1016', 1, verified: false),
    ],
  ),

  // --------------------------------------------------------------- Skills
  Competency(
    id: 'CMP-010',
    name: 'Project Management',
    category: CompetencyCategory.skill,
    description: 'Planning, running and delivering projects on time: scope, '
        'schedule, risks, people and stakeholders.',
    levelDescriptions: const [
      'Knows the basic terms: scope, milestones, tasks and deadlines.',
      'Tracks own tasks and reports progress and blockers on time.',
      'Plans and runs a small project or workstream with a few people.',
      'Manages full projects: budget, risks, dependencies and stakeholder updates.',
      'Runs several projects or a programme; mentors other project leads.',
      'Shapes how the organisation plans and delivers projects.',
    ],
    createdAt: DateTime(2026, 5, 6),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1001', 4),
      CompetencyHolder('EMP-1013', 3),
      CompetencyHolder('EMP-1019', 3),
      CompetencyHolder('EMP-1025', 4),
      CompetencyHolder('EMP-1030', 3),
      CompetencyHolder('EMP-1034', 4),
    ],
  ),
  Competency(
    id: 'CMP-011',
    name: 'Microservices',
    category: CompetencyCategory.skill,
    description: 'Designing applications as small services that are deployed on '
        'their own and talk over APIs and events.',
    levelDescriptions: const [
      'Understands how microservices differ from a single monolithic app.',
      'Works on an existing service and calls other services\' REST APIs.',
      'Builds a service end to end with its own data, config and health checks.',
      'Handles service-to-service calls, retries, messaging and tracing.',
      'Designs service boundaries, API contracts and data consistency.',
      'Sets the microservices architecture direction for the organisation.',
    ],
    createdAt: DateTime(2026, 5, 6),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1001', 4),
      CompetencyHolder('EMP-1002', 3),
      CompetencyHolder('EMP-1003', 2),
      CompetencyHolder('EMP-1009', 2, verified: false),
      CompetencyHolder('EMP-1012', 3),
    ],
  ),
  Competency(
    id: 'CMP-012',
    name: 'UX Research',
    category: CompetencyCategory.skill,
    description: 'Understanding users through interviews, usability tests and data, '
        'so we build the right product.',
    levelDescriptions: const [
      'Understands why user research matters and the common methods.',
      'Takes notes and helps run interviews or usability sessions.',
      'Plans and runs usability tests and interviews; summarises findings.',
      'Picks the right methods and turns findings into design decisions.',
      'Leads research programmes; builds personas and journey maps.',
      'Sets research practice and standards across the organisation.',
    ],
    createdAt: DateTime(2026, 6, 15),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1030', 4),
      CompetencyHolder('EMP-1031', 1, verified: false),
      CompetencyHolder('EMP-1032', 4),
    ],
  ),
  Competency(
    id: 'CMP-013',
    name: 'Machine Learning',
    category: CompetencyCategory.skill,
    description: 'Building models that learn from data to predict, classify or '
        'recommend.',
    levelDescriptions: const [
      'Knows the basic ideas: training data, features, models and predictions.',
      'Trains simple models with existing libraries by following a guide.',
      'Prepares data, trains and evaluates common models, avoids overfitting.',
      'Builds and tunes models for real business problems and explains results.',
      'Deploys and monitors models in production; designs ML pipelines.',
      'Leads ML strategy and research for the organisation.',
    ],
    createdAt: DateTime(2026, 7, 2),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1019', 3),
      CompetencyHolder('EMP-1023', 4),
    ],
  ),

  // -------------------------------------------------------------- Domains
  Competency(
    id: 'CMP-014',
    name: 'Atlassian',
    category: CompetencyCategory.domain,
    description: 'Knowledge of the Atlassian ecosystem (Jira, Confluence, Bitbucket '
        'and Marketplace apps) for delivery and client projects.',
    levelDescriptions: const [
      'Knows the Atlassian products and what each one is used for.',
      'Uses Jira and Confluence every day following team conventions.',
      'Connects the tools together; sets up spaces, projects and permissions.',
      'Delivers client work on Atlassian products: setup, migration, integrations.',
      'Plans enterprise roll-outs and cloud migrations; builds automation or apps.',
      'Recognised ecosystem expert who advises clients and leadership.',
    ],
    createdAt: DateTime(2026, 8, 20),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1013', 2),
      CompetencyHolder('EMP-1015', 3),
    ],
  ),
  Competency(
    id: 'CMP-015',
    name: 'Banking & Payments',
    category: CompetencyCategory.domain,
    description: 'Business knowledge of banking and digital payments: accounts, '
        'cards, UPI, settlement, compliance and fraud.',
    levelDescriptions: const [
      'Knows the basic terms: accounts, transactions, cards and payment methods.',
      'Understands how a payment flows between customer, merchant and bank.',
      'Builds payment features knowing settlement, refunds and reconciliation.',
      'Applies regulations, card-data security and fraud controls in daily work.',
      'Designs payment solutions with the business and guides teams on the rules.',
      'Domain authority who advises clients and leadership.',
    ],
    createdAt: DateTime(2026, 9, 1),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1001', 3),
      CompetencyHolder('EMP-1002', 2),
      CompetencyHolder('EMP-1003', 2),
      CompetencyHolder('EMP-1009', 1),
      CompetencyHolder('EMP-1013', 2, verified: false),
      CompetencyHolder('EMP-1017', 1, verified: false),
      CompetencyHolder('EMP-1025', 2),
      CompetencyHolder('EMP-1028', 1),
    ],
  ),
  Competency(
    id: 'CMP-016',
    name: 'HR & Talent Management',
    category: CompetencyCategory.domain,
    description: 'How organisations hire, grow, assess and keep people: recruitment, '
        'onboarding, performance and learning.',
    levelDescriptions: const [
      'Knows the employee life cycle from hiring to exit.',
      'Supports recruitment, onboarding or training tasks with guidance.',
      'Runs HR processes for a team: hiring rounds, onboarding plans, reviews.',
      'Owns a function such as hiring or L&D and uses HR data in decisions.',
      'Designs competency frameworks, career paths and performance programmes.',
      'Sets the people strategy for the organisation and advises leadership.',
    ],
    createdAt: DateTime(2026, 9, 1),
    createdBy: _hrd,
    holders: const [
      CompetencyHolder('EMP-1034', 5),
      CompetencyHolder('EMP-1035', 3),
      CompetencyHolder('EMP-1036', 3),
    ],
  ),
];
