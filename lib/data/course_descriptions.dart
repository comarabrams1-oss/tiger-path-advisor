/// Plain-language summaries of Benedict College's 2025–2026 Catalogue.
/// These entries explain course content. Degree and enrollment rules are
/// maintained separately in the program mappings.
const courseDescriptions = <String, (String, int, String)>{
  'AA 111': (
    'The College Experience',
    84,
    'Get oriented to Benedict College and practice study skills, time management, professional etiquette and finding campus resources.',
  ),
  'AA 211': (
    'Professional Pathways Development',
    84,
    'Explore career paths and practice skills for finding work, staying employed and pursuing new opportunities.',
  ),
  'AR 130': (
    'Elementary Arabic',
    183,
    'Start with the Arabic alphabet and learn basic vocabulary and grammar.',
  ),
  'AR 233': (
    'Intermediate Arabic',
    183,
    'Build on elementary Arabic by practicing speaking, reading and writing.',
  ),
  'ART 130': (
    'Art Appreciation',
    191,
    'Learn how to look at and interpret visual art. Study elements of design, the materials artists use and how art reflects its cultural setting.',
  ),
  'BIO 117L': (
    'Principles of Biology I Lab',
    245,
    'Practice lab safety, measurement and scientific methods while studying cells, heredity, taxonomy and the diversity of life.',
  ),
  'BIO 118L': (
    'Principles of Biology II Lab',
    245,
    'Explore photosynthesis, nutrition, gas exchange, transport, nervous systems and ecology through lab work.',
  ),
  'BIO 137': (
    'Principles of Biology I',
    245,
    'Study foundational biology, including the chemistry of life, cells, genetics, heredity, ecology and natural selection.',
  ),
  'BIO 138': (
    'Principles of Biology II',
    245,
    'Build on Biology I with metabolism, plant and animal organ systems, and patterns of evolution.',
  ),
  'CE 211L': (
    'Digital Circuits Lab',
    290,
    'Build, simulate and test combinational and sequential logic circuits. Compare your measurements with the predicted results.',
  ),
  'CE 231': (
    'Digital Circuits',
    290,
    'Use binary numbers and logic gates to design and analyze combinational and sequential circuits. Work with simulations and hardware.',
  ),
  'CE 332': (
    'Embedded Systems',
    291,
    'Program ARM-based microcontrollers and connect them to sensors and actuators. Learn about interrupts, peripherals and embedded Internet of Things designs.',
  ),
  'CE 427': (
    'Senior Design Project I',
    291,
    'Plan and design a solution to an engineering problem with faculty supervision. Apply concepts from previous engineering courses to a project.',
  ),
  'CE 428': (
    'Senior Design Project II',
    291,
    'Finish the engineering design project begun in CE 427, write a report and defend the project in front of faculty and students.',
  ),
  'CE 436': (
    'VLSI System Design',
    291,
    'Design complex digital circuits for CMOS chips. Use commercial design tools and study how smaller circuit cells fit into larger integrated systems.',
  ),
  'CE 437': (
    'Computer Network Hardware',
    291,
    'Study how network hardware moves data through Ethernet, switches and routers. The course also covers routing, queuing and cellular networks.',
  ),
  'CHEM 117L': (
    'Principles of Chemistry I Lab',
    260,
    'Practice measurements, safe chemical handling and recording results while studying properties of matter and chemical reactions.',
  ),
  'CHEM 118L': (
    'Principles of Chemistry II Lab',
    260,
    'Run experiments involving solutions, equilibrium, reaction rates and acid–base titration. Practice identifying inorganic ions.',
  ),
  'CHEM 137': (
    'Principles of Chemistry I',
    260,
    'Study atomic structure, chemical bonding, periodic trends and chemical equations, with some examples from industrial chemistry.',
  ),
  'CHEM 138': (
    'Principles of Chemistry II',
    260,
    'Build on general chemistry with solutions, oxidation and reduction, equilibrium and thermochemistry. The course introduces organic chemistry and qualitative analysis.',
  ),
  'CSC 132': (
    'Introduction to Computing and Programming Logic',
    282,
    'Learn how hardware, software and operating systems work together, and how to break a problem into steps a program can follow.',
  ),
  'CSC 133': (
    'Digital Logic',
    282,
    'Use binary numbers and logic gates to understand digital circuits, memory, processors and control logic.',
  ),
  'CSC 135': (
    'Introduction to Programming',
    282,
    'Write and debug C++ programs using variables, control flow, arrays, functions and recursion. The course also introduces pointers and structures.',
  ),
  'CSC 136': (
    'Algorithm Design I',
    282,
    'Practice problem solving in C++ using functions, arrays, strings, classes and objects.',
  ),
  'CSC 138': (
    'Object-Oriented Programming',
    282,
    'Solve problems with classes and objects. Learn encapsulation, inheritance, polymorphism, overloading and basic abstract data types.',
  ),
  'CSC 139': (
    'Web Development',
    282,
    'Plan and build websites with HTML, CSS and JavaScript using web standards.',
  ),
  'CSC 231': (
    'Assembly Language',
    282,
    'Learn low-level programming for IBM PC-compatible systems. Study registers, instruction formats, input and output, debugging and testing.',
  ),
  'CSC 232': (
    'Foundations of App Development',
    282,
    'Start programming in Swift and explore iOS app development. Take an app idea through brainstorming, planning, prototyping and evaluation.',
  ),
  'CSC 233': (
    'Data Structures and Algorithms I',
    282,
    'Study linked lists, stacks, queues, searching and sorting. Use asymptotic notation such as Big O to compare time and memory costs.',
  ),
  'CSC 234': (
    'Theory of Computations',
    283,
    'Study what formal models of computers can do. Topics include automata, Turing machines, language classes and proofs about programs.',
  ),
  'CSC 235': (
    'Fundamentals of App Development',
    283,
    'Build iOS apps with Swift and learn to use Xcode’s code and interface editors. Practice using standard iOS interface components.',
  ),
  'CSC 237': (
    'Java Programming',
    283,
    'Write Java programs using objects, exceptions and graphical interfaces. The course also covers threads, file input and output, and networking.',
  ),
  'CSC 238': (
    'Introduction to Computer Security',
    283,
    'Learn the basics of protecting computer systems, including authentication, certificates, firewalls, security policy, ethics and incident handling.',
  ),
  'CSC 334': (
    'Data Structures and Algorithms II',
    283,
    'Build on Data Structures I with hash tables, trees, graphs and their algorithms. Compare how solutions use time and memory.',
  ),
  'CSC 336': (
    'Advanced Concepts in App Development',
    284,
    'Build more complex iOS apps that use server data and display larger collections. The course introduces Core ML and additional iOS APIs.',
  ),
  'CSC 337': (
    'Computer Organization and Architecture',
    284,
    'Learn how the components of a computer fit together. Topics include instruction sets, storage, input and output, and connections between components.',
  ),
  'CSC 338': (
    'Introduction to Artificial Intelligence',
    284,
    'Study how AI systems search for solutions and make decisions. Topics include heuristics, Bayesian reasoning, robotics and supervised, unsupervised and reinforcement learning.',
  ),
  'CSC 339': (
    'Data Communication and Networking',
    284,
    'Learn how computers exchange data through TCP/IP, wired and wireless networks, and internet services. The course introduces network protections such as firewalls and VPNs.',
  ),
  'CSC 430': (
    'Senior Research and Professional Experience',
    284,
    'Investigate a computer science topic with faculty supervision and present your findings. Discuss professional, ethical and social responsibilities in computing.',
  ),
  'CSC 431': (
    'Programming Languages',
    284,
    'Compare programming language features and design choices. Study syntax, meaning and how language constructs are implemented.',
  ),
  'CSC 434': (
    'Database Management',
    284,
    'Learn how databases organize and process data. Study database models and relational design, and use SQL to work with stored information.',
  ),
  'CSC 435': (
    'Software Engineering Principles',
    285,
    'Study how software projects are designed, built and managed throughout the development lifecycle.',
  ),
  'CSC 436': (
    'Operating Systems',
    285,
    'Learn how operating systems manage processes, scheduling, memory, files and devices. Topics include concurrency, synchronization and system protection.',
  ),
  'CSC 437': (
    'Senior Capstone',
    285,
    'Build a substantial software project individually or in a team. A faculty member supervises the work and a committee evaluates the result.',
  ),
  'EE 211L': (
    'Circuits I Lab',
    288,
    'Use meters, oscilloscopes and simulation tools to measure and check voltage and current in circuits with resistors, capacitors and inductors.',
  ),
  'EE 212L': (
    'Circuits II Lab',
    288,
    'Use lab equipment and simulation to measure frequency response and how circuits react when their inputs change.',
  ),
  'EE 213L': (
    'Electronics I Lab',
    288,
    'Measure and simulate circuits built with diodes and transistors. Compare hardware measurements with circuit models.',
  ),
  'EE 231': (
    'Circuits I',
    288,
    'Learn to analyze and design linear circuits using voltage, current, power, impedance and methods such as mesh and nodal analysis.',
  ),
  'EE 232': (
    'Circuits II',
    288,
    'Build on Circuits I with transient response, filters, operational amplifiers, Laplace transforms and Fourier analysis.',
  ),
  'EE 233': (
    'Electronics I',
    288,
    'Study semiconductor devices and circuits using diodes and transistors. Topics include biasing, amplification and switching.',
  ),
  'EE 314L': (
    'Electronics II Lab',
    289,
    'Build and measure amplifier circuits, then compare your AC and DC measurements with circuit simulations.',
  ),
  'EE 330': (
    'Systems and Signals',
    289,
    'Analyze linear systems with differential equations, Fourier and Laplace methods, transfer functions and basic analog filter design.',
  ),
  'EE 332': (
    'Digital Signal Processing',
    289,
    'Study sampled signals and discrete-time systems. Use Fourier and Z transforms to analyze signals and design digital filters.',
  ),
  'EE 333': (
    'Electromagnetics',
    289,
    'Study electric and magnetic fields, Maxwell’s equations, and how electromagnetic waves propagate through space and materials.',
  ),
  'EE 334': (
    'Electronics II',
    289,
    'Study linear integrated circuits, including operational amplifiers, frequency response, active filters, comparators and wave generators.',
  ),
  'EE 427': (
    'Senior Design Project I',
    289,
    'Plan and design a faculty-supervised engineering project that applies knowledge from your undergraduate courses.',
  ),
  'EE 428': (
    'Senior Design Project II',
    289,
    'Complete the engineering project begun in EE 427, write a report and present a defense to faculty and students.',
  ),
  'EE 431': (
    'Communication Systems',
    290,
    'Study how signals are transmitted and shared across channels. Topics include spectral analysis, modulation, multiplexing and digital communication.',
  ),
  'EE 433': (
    'Electric Energy and Power Systems',
    290,
    'Study three-phase circuits, transformers, generators, motors and transmission lines in electric power systems.',
  ),
  'EE 434': (
    'Control Systems',
    290,
    'Analyze and design control systems. Use transfer functions and state-space models to study response and stability.',
  ),
  'EE 435': (
    'Applied Electromagnetics',
    290,
    'Apply electromagnetic theory to transmission lines, waveguides, radiation, electro-optics and interference.',
  ),
  'EE 436': (
    'Programmable Logic Controllers',
    290,
    'Learn how programmable logic controllers work and how they are used to automate industrial equipment and processes.',
  ),
  'ENG 131': (
    'Analysis and Argumentation',
    178,
    'Practice reading critically and writing clear academic arguments. Use evidence, reasoning and the writing process to develop ideas for an audience.',
  ),
  'ENG 132': (
    'Information Literacy and Research',
    178,
    'Build on analytical writing by finding, evaluating, synthesizing and responsibly using sources in research writing.',
  ),
  'ENG 237': (
    'Oral Communication',
    179,
    'Practice organizing and delivering spoken messages. Work on supporting ideas with evidence and communicating effectively with different audiences.',
  ),
  'ENGR 130': (
    'Introduction to Engineering',
    287,
    'Explore engineering through problem solving, teamwork, communication and professional ethics. Practice working with units and quantitative problems.',
  ),
  'ENGR 132': (
    'Introduction to Engineering Software',
    294,
    'Use engineering software for computer-aided drawing and geographic information systems. Learn basic CAD and two- and three-dimensional drawing.',
  ),
  'ENGR 321': (
    'Engineering Professional Development',
    287,
    'Prepare to pursue engineering jobs or further study. The course introduces professional licensure, certification and career preparation.',
  ),
  'ENGR 331': (
    'Engineering Economics',
    288,
    'Compare engineering options using costs, benefits, risk and resource decisions. Study how economics affects equipment and project choices.',
  ),
  'FS 130': (
    'Elementary French',
    183,
    'Start learning French with basic grammar and vocabulary.',
  ),
  'FS 233': (
    'Intermediate French',
    183,
    'Build on elementary French by practicing speaking, reading and writing.',
  ),
  'HIST 130': (
    'Introduction to African American History',
    227,
    'Explore African American history from ancient African societies through the modern civil rights movement, including the forced migration of African peoples and their experiences in the Americas.',
  ),
  'MATH 134': (
    'General College Mathematics II',
    278,
    'Explore practical uses of mathematics in daily life and develop mathematical reasoning.',
  ),
  'MATH 138': (
    'College Algebra',
    278,
    'Work with equations, polynomials, radicals, functions and their graphs. Topics include inverse functions and polynomial division.',
  ),
  'MATH 139': (
    'Precalculus',
    278,
    'Prepare for calculus and science courses by studying trigonometric functions, identities and applications.',
  ),
  'MATH 143': (
    'Calculus I',
    278,
    'Study limits, continuity and derivatives. Apply differential calculus to problems involving functions of one variable.',
  ),
  'MATH 144': (
    'Calculus II',
    279,
    'Continue calculus with integration techniques, sequences and infinite series.',
  ),
  'MATH 230': (
    'Linear Algebra',
    279,
    'Use matrices to solve systems of linear equations. Learn about determinants, vector spaces and linear transformations.',
  ),
  'MATH 236': (
    'Probability and Statistics',
    279,
    'Summarize data with graphs and statistics and study probability, including Bayes’ theorem and probability distributions.',
  ),
  'MATH 237': (
    'Differential Equations I',
    279,
    'Solve ordinary differential equations with methods such as Laplace transforms and series. Apply the methods to science and engineering.',
  ),
  'MATH 238': (
    'Differential Equations II',
    279,
    'Study when differential equation solutions exist and are unique. Use power series and eigenvalue methods to solve equations and systems.',
  ),
  'MATH 241': (
    'Calculus III',
    279,
    'Extend calculus to functions of more than one variable. The course focuses on multivariable calculus for science, engineering and mathematics.',
  ),
  'MATH 336': (
    'Discrete Mathematics',
    280,
    'Practice logic, proofs and induction. Study sets, counting, combinations, recurrence relations and related ideas used in computing.',
  ),
  'MUS 130': (
    'Music Appreciation',
    200,
    'Learn to listen closely and discuss music from different periods, styles and genres. Explore how music relates to culture, history and other arts.',
  ),
  'PHIL 330': (
    'Critical Thinking and Logic',
    232,
    'Learn to evaluate and construct arguments using deductive and inductive reasoning and propositional logic.',
  ),
  'PHYS 231': (
    'General Physics I',
    272,
    'Study foundational physics topics including mechanics, waves and heat.',
  ),
  'PHYS 232': (
    'General Physics II',
    272,
    'Build on General Physics I with electricity, magnetism, light and an introduction to modern physics.',
  ),
  'PHYS 213L': (
    'Principles of Physics I Lab',
    273,
    'Run experiments in mechanics, waves and thermal physics.',
  ),
  'PHYS 214L': (
    'Principles of Physics II Lab',
    273,
    'Run experiments on electricity, magnetism, light and optics.',
  ),
  'PHYS 233': (
    'Principles of Physics I',
    273,
    'Use calculus to study mechanics, waves and thermal physics.',
  ),
  'PHYS 234': (
    'Principles of Physics II',
    273,
    'Continue the Principles of Physics sequence with electricity, magnetism, light and optics.',
  ),
  'PHYS 331': (
    'Statics',
    273,
    'Analyze how forces balance in stationary systems. Apply vectors and equilibrium to structures such as trusses, frames and beams.',
  ),
  'PHYS 332': (
    'Dynamics',
    273,
    'Study how particles and rigid bodies move. Topics include work, energy, oscillations and moving reference frames.',
  ),
  'PHYS 333': (
    'Principles of Physics III',
    273,
    'Explore modern physics, including relativity, quantum theory, and atomic, nuclear and solid-state physics.',
  ),
  'PHYS 334': (
    'Thermal Physics',
    273,
    'Study thermodynamics, entropy, equilibrium, heat engines and introductory statistical mechanics.',
  ),
  'PHYS 336': (
    'Electricity and Magnetism',
    273,
    'Study electric and magnetic fields in depth, including induction, electromagnetic waves and Maxwell’s equations.',
  ),
  'PHYS 338': (
    'Modern Electronics',
    274,
    'Study semiconductor electronics and AC and DC circuits. Learn about diodes, transistors, amplifiers and integrated circuits.',
  ),
  'PHYS 431': (
    'Modern Physics I',
    274,
    'Study relativity, quantum effects and atomic structure at an advanced level.',
  ),
  'PHYS 432': (
    'Modern Physics II',
    274,
    'Continue modern physics with nuclear, molecular and solid-state physics and elementary particles. The course includes a research paper.',
  ),
  'PHYS 434': (
    'Advanced Modern Physics Laboratory',
    274,
    'Practice advanced experimental techniques and complete laboratory projects in modern physics.',
  ),
  'PHYS 435': (
    'Optics',
    274,
    'Study the behavior of light through lenses, interferometers, gratings and thin films. Topics include polarization and the wave nature of light.',
  ),
  'PHYS 436': (
    'Introduction to Quantum Mechanics',
    274,
    'Study basic quantum theory, including operators, the wave equation and perturbation methods.',
  ),
  'POLS 233': (
    'American National Government',
    229,
    'Study how the U.S. national government evolved, how it is organized, and how it exercises its powers within the political process.',
  ),
  'PSY 130': (
    'General Psychology',
    138,
    'Explore how psychologists study behavior and mental processes. Topics include research methods, development, learning, memory, perception and motivation.',
  ),
  'REL 130': (
    'Comparative Religion',
    235,
    'Compare major world religions, their beliefs and how they relate to one another. Examine common biases in interpreting religious traditions.',
  ),
  'SP 130': (
    'Elementary Spanish',
    183,
    'Start learning Spanish with basic grammar and vocabulary.',
  ),
  'SP 233': (
    'Intermediate Spanish',
    183,
    'Build on elementary Spanish by practicing speaking, reading and writing.',
  ),
  'THE 230': (
    'Theatre Appreciation',
    207,
    'Explore the art, craft and business of theatre. Study plays and theatrical styles to see how different artists work together on a production.',
  ),
};
