// Demo graphs showing what VGraph can do, for any front end: the editor's
// "Examples" menu, and the tests that prove every one still works. Raw string
// delimiters (#""" """#) keep the VGL verbatim.

public struct ExampleGraph: Sendable {
    public let name: String
    public let vgl: String

    public init(name: String, vgl: String) {
        self.name = name
        self.vgl = vgl
    }
}

public let exampleGraphs: [ExampleGraph] = [
    ExampleGraph(
        name: #"BBS — Customer Satisfaction Initiative"#,
        vgl: #"""
            vgraph customerSatisfaction: BBS "Customer Satisfaction Initiative" {
                node obj1: InvestmentObjective "Increase Customer Satisfaction by 25%";
                node ben1: Benefit "Faster Response Times";
                node ben2: Benefit "Improved Service Quality";
                node ben3: Benefit "24/7 Support Availability";
                node chg1: BusinessChange "Automated Ticket Routing";
                node chg2: BusinessChange "Self-Service Portal";
                node chg3: BusinessChange "Staff Training Program";
                node chg4: BusinessChange "24/7 Shift Coverage";
                node enb1: Enabler "AI-Powered Ticketing System";
                node enb2: Enabler "Customer Portal Platform";
                node enb3: Enabler "Training Materials & LMS";
                node enb4: Enabler "Staffing & Scheduling System";

                edge ben1 -> obj1: requires_benefit;
                edge ben2 -> obj1: requires_benefit;
                edge ben3 -> obj1: requires_benefit;
                edge chg1 -> ben1: requires_business_change;
                edge chg2 -> ben2: requires_business_change;
                edge chg3 -> ben2: requires_business_change;
                edge chg4 -> ben3: requires_business_change;
                edge enb1 -> chg1: requires_enabler;
                edge enb2 -> chg2: requires_enabler;
                edge enb3 -> chg3: requires_enabler;
                edge enb4 -> chg4: requires_enabler;
                edge chg1 -> chg2: change_requires_change;
                edge enb1 -> enb2: enabler_requires_enabler;
            }
            """#),
    ExampleGraph(
        name: #"ImpactMapping — Mobile App Launch"#,
        vgl: #"""
            vgraph mobileApp: ImpactMapping "Mobile App Launch" {
                node g1: Goal "Increase Revenue by 30%";
                node a1: Actor "New Customers";
                node a2: Actor "Existing Customers";
                node i1: Impact "Make First Purchase";
                node i2: Impact "Increase Purchase Frequency";
                node i3: Impact "Upgrade to Premium";
                node d1: Deliverable "Mobile App with Easy Checkout";
                node d2: Deliverable "Push Notifications for Deals";
                node d3: Deliverable "Loyalty Rewards Program";
                node d4: Deliverable "Premium Features Bundle";

                edge g1 -> a1: goal_to_actor;
                edge g1 -> a2: goal_to_actor;
                edge a1 -> i1: actor_to_impact;
                edge a2 -> i2: actor_to_impact;
                edge a2 -> i3: actor_to_impact;
                edge i1 -> d1: impact_to_deliverable;
                edge i2 -> d2: impact_to_deliverable;
                edge i2 -> d3: impact_to_deliverable;
                edge i3 -> d4: impact_to_deliverable;
            }
            """#),
    ExampleGraph(
        name: #"ConceptMap — How Learning Works"#,
        vgl: #"""
            vgraph learningCM: ConceptMap "How Learning Works" {
                node c1: Concept "Student";
                node r1: Relation "learns";
                node c2: Concept "Subject";
                node r2: Relation "requires";
                node c3: EmphasizedConcept "Practice";
                node r3: Relation "leads to";
                node c4: Concept "Understanding";
                node r4: Relation "uses";
                node c5: Concept "Resources";

                edge c1 -> r1: concept_to_relation;
                edge r1 -> c2: relation_to_concept;
                edge c2 -> r2: concept_to_relation;
                edge r2 -> c3: relation_to_emphasized_concept;
                edge c3 -> r3: emphasized_concept_to_relation;
                edge r3 -> c4: relation_to_concept;
                edge c2 -> r4: concept_to_relation;
                edge r4 -> c5: relation_to_concept;
            }
            """#),
    ExampleGraph(
        name: #"Annotation extension — Product Strategy Map"#,
        vgl: #"""
            vgraph productStrategy: ConceptMap, Annotation "Product Strategy Map" {
                node c1: Concept "Customer Need";
                node r1: Relation "drives";
                node c2: Concept "Feature";
                node r2: Relation "is delivered by";
                node c3: Concept "Release";
                node r3: Relation "is measured by";
                node c4: Concept "Adoption";
                node r4: Relation "is limited by";
                node c5: Concept "Team Capacity";
                node a1: Annotation "Validated in 12 user interviews";
                node a2: Annotation "Owned by the platform team";
                node w1: Warning "Release date depends on a vendor contract";

                edge c1 -> r1;
                edge r1 -> c2;
                edge c2 -> r2;
                edge r2 -> c3;
                edge c3 -> r3;
                edge r3 -> c4;
                edge c2 -> r4;
                edge r4 -> c5;
                edge c1 -> a1;
                edge c2 -> a2;
                edge c3 -> w1;
            }
            """#),
    ExampleGraph(
        name: #"IBIS — Complex System Architecture Decision"#,
        vgl: #"""
            vgraph complexSystem: IBIS "Complex System Architecture Decision" {
                // Main question and primary answers
                node q1: Question "What architecture should we use for the new platform?";
                node a1: Answer "Microservices Architecture";
                node a2: Answer "Monolithic Architecture";
                node a3: Answer "Serverless Architecture";
                node a4: Answer "Hybrid Architecture";

                // Arguments for Microservices
                node pro1: Pro "Better scalability for individual services";
                node pro2: Pro "Independent deployment cycles";
                node pro3: Pro "Technology diversity possible";
                node pro4: Pro "Fault isolation";
                node pro5: Pro "Team autonomy";
                node con1: Con "Increased operational complexity";
                node con2: Con "Distributed system challenges";
                node con3: Con "Network latency overhead";
                node con4: Con "Data consistency challenges";

                // Arguments for Monolithic
                node pro6: Pro "Simpler deployment process";
                node pro7: Pro "Easier to debug and test";
                node pro8: Pro "Better performance for internal calls";
                node pro9: Pro "Simpler data consistency";
                node con5: Con "Scaling requires entire system";
                node con6: Con "Tight coupling of components";
                node con7: Con "Limited technology choices";
                node con8: Con "Slower development cycles";

                // Arguments for Serverless
                node pro10: Pro "No infrastructure management";
                node pro11: Pro "Automatic scaling";
                node pro12: Pro "Pay per execution model";
                node pro13: Pro "Built-in high availability";
                node con9: Con "Vendor lock-in concerns";
                node con10: Con "Cold start latency";
                node con11: Con "Limited execution time";
                node con12: Con "Difficult to debug";

                // Arguments for Hybrid
                node pro14: Pro "Flexibility to choose per component";
                node pro15: Pro "Gradual migration path";
                node pro16: Pro "Optimize costs per workload";
                node con13: Con "Most complex to manage";
                node con14: Con "Requires expertise in multiple patterns";
                node con15: Con "Inconsistent deployment processes";

                // Sub-questions
                node q2: Question "How will we handle data management?";
                node q3: Question "What about team structure?";
                node q4: Question "How do we ensure security?";
                node q5: Question "What monitoring approach?";

                // Data management answers
                node a5: Answer "Database per service";
                node a6: Answer "Shared database";
                node a7: Answer "Event sourcing";

                // Team structure answers
                node a8: Answer "Service-oriented teams";
                node a9: Answer "Feature teams";
                node a10: Answer "Platform teams";

                // Security answers
                node a11: Answer "API Gateway with OAuth2";
                node a12: Answer "Service mesh with mTLS";
                node a13: Answer "Zero trust architecture";

                // Monitoring answers
                node a14: Answer "Centralized logging";
                node a15: Answer "Distributed tracing";
                node a16: Answer "Application performance monitoring";

                // Main question edges
                edge q1 -> a1;
                edge q1 -> a2;
                edge q1 -> a3;
                edge q1 -> a4;

                // Microservices arguments
                edge a1 -> pro1;
                edge a1 -> pro2;
                edge a1 -> pro3;
                edge a1 -> pro4;
                edge a1 -> pro5;
                edge a1 -> con1;
                edge a1 -> con2;
                edge a1 -> con3;
                edge a1 -> con4;

                // Monolithic arguments
                edge a2 -> pro6;
                edge a2 -> pro7;
                edge a2 -> pro8;
                edge a2 -> pro9;
                edge a2 -> con5;
                edge a2 -> con6;
                edge a2 -> con7;
                edge a2 -> con8;

                // Serverless arguments
                edge a3 -> pro10;
                edge a3 -> pro11;
                edge a3 -> pro12;
                edge a3 -> pro13;
                edge a3 -> con9;
                edge a3 -> con10;
                edge a3 -> con11;
                edge a3 -> con12;

                // Hybrid arguments
                edge a4 -> pro14;
                edge a4 -> pro15;
                edge a4 -> pro16;
                edge a4 -> con13;
                edge a4 -> con14;
                edge a4 -> con15;

                // Sub-question relationships
                edge a1 -> q2 [label: "raises"];
                edge a1 -> q3 [label: "raises"];
                edge a1 -> q4 [label: "raises"];
                edge a1 -> q5 [label: "raises"];

                // Data management sub-question
                edge q2 -> a5;
                edge q2 -> a6;
                edge q2 -> a7;

                // Team structure sub-question
                edge q3 -> a8;
                edge q3 -> a9;
                edge q3 -> a10;

                // Security sub-question
                edge q4 -> a11;
                edge q4 -> a12;
                edge q4 -> a13;

                // Monitoring sub-question
                edge q5 -> a14;
                edge q5 -> a15;
                edge q5 -> a16;
            }
            """#),
    ExampleGraph(
        name: #"IBIS — Software Project Planning"#,
        vgl: #"""
            vgraph projectPlanning: IBIS "Software Project Planning" {
                node q1: Question "How should we approach this project?";

                group planning "Phase 1: Planning" {
                    node a1: Answer "Start with thorough planning";
                    node pro1: Pro "Reduces risks early";
                    node con1: Con "Takes more time upfront";

                    group requirements "Requirements Analysis" {
                        node q2: Question "What are the key requirements?";
                        node a2: Answer "Focus on user needs";
                        node a3: Answer "Focus on technical constraints";
                        node pro2: Pro "User-centered approach";
                        node con2: Con "May miss technical issues";
                    };

                    group timeline "Timeline Planning" {
                        node q3: Question "What timeline is realistic?";
                        node a4: Answer "3-month sprint cycles";
                        node a5: Answer "6-month waterfall phases";
                        node pro3: Pro "Faster feedback loops";
                        node pro4: Pro "More predictable delivery";
                    };
                };

                group implementation "Phase 2: Implementation" {
                    node a6: Answer "Move fast and iterate";
                    node pro5: Pro "Quick time to market";
                    node con3: Con "May accumulate tech debt";

                    group testing "Testing Strategy" {
                        node q4: Question "How do we ensure quality?";
                        node a7: Answer "Test-driven development";
                        node a8: Answer "QA team testing";
                        node pro6: Pro "Catches bugs early";
                        node con4: Con "Slower initial development";
                    };
                };

                edge q1 -> a1;
                edge q1 -> a6;
                edge a1 -> pro1;
                edge a1 -> con1;

                edge a1 -> q2;
                edge q2 -> a2;
                edge q2 -> a3;
                edge a2 -> pro2;
                edge a2 -> con2;

                edge a1 -> q3;
                edge q3 -> a4;
                edge q3 -> a5;
                edge a4 -> pro3;
                edge a5 -> pro4;

                edge a6 -> pro5;
                edge a6 -> con3;
                edge a6 -> q4;
                edge q4 -> a7;
                edge q4 -> a8;
                edge a7 -> pro6;
                edge a7 -> con4;
            }
            """#),
    ExampleGraph(
        name: #"FRT — Sales Improvement Plan"#,
        vgl: #"""
            vgraph salesSolution: FRT "Sales Improvement Plan" {
                // Changeable nodes (injections/solutions we will implement)
                node c1: Changeable "Implement agile product development";
                node c2: Changeable "Hire additional support staff";
                node c3: Changeable "Create customer feedback system";

                // Given (unchangeable facts that still apply)
                node g1: Given "Market is highly competitive";
                node g2: Given "Customer expectations keep rising";

                // Intermediate Effects (expected outcomes from our solutions)
                node ie1: IntermediateEffect "Faster product iterations";
                node ie2: IntermediateEffect "Products match customer needs";
                node ie3: IntermediateEffect "Support response time improves";
                node ie4: IntermediateEffect "Customer feedback drives development";

                // And Junctor (multiple conditions required together for an effect)
                node and1: AndJunctor;

                // Desirable Effects (the goals we want to achieve)
                node de1: DesirableEffect "Sales revenue increasing";
                node de2: DesirableEffect "Customer satisfaction high";
                node de3: DesirableEffect "Market share growing";

                // Some undesirable effects that might still occur (to monitor)
                node ude1: UndesirableEffect "Initial implementation costs";

                // Solutions flow upward to desired outcomes
                edge c1 -> ie1: changeable_causes_intermediate;
                edge c3 -> ie4: changeable_causes_intermediate;
                edge c2 -> ie3: changeable_causes_intermediate;

                // Given facts combining with solutions
                edge g2 -> and1: given_to_and_junctor;
                edge ie4 -> and1: intermediate_to_and_junctor;

                // And junctor combining conditions
                edge and1 -> ie2: and_junctor_causes_intermediate;

                // Multiple alternative paths to customer satisfaction (implicit OR)
                edge ie2 -> de2: intermediate_causes_desirable;
                edge ie3 -> de2: intermediate_causes_desirable;

                // Intermediate effects leading to desirable effects
                edge ie1 -> de3: intermediate_causes_desirable;
                edge ie2 -> de1: intermediate_causes_desirable;
                edge ie2 -> de3: intermediate_causes_desirable;

                // Acknowledging potential downsides
                edge c1 -> ude1: changeable_causes_undesirable;
                edge c2 -> ude1: changeable_causes_undesirable;

                // Given competitive market affects outcomes
                edge g1 -> ie2: given_causes_intermediate;
            }
            """#),
    ExampleGraph(
        name: #"PRT — New Product Launch Planning"#,
        vgl: #"""
            vgraph projectLaunch: PRT "New Product Launch Planning" {
                // The main objective we want to achieve
                node obj1: Objective "Successfully launch product by Q3";

                // Obstacles blocking the main objective
                node obs1: Obstacle "Development team lacks required skills";
                node obs2: Obstacle "Marketing budget not approved";
                node obs3: Obstacle "No distribution channel established";

                // Intermediate objectives to overcome obstacles
                node io1: IntermediateObjective "Train team on new technology";
                node io2: IntermediateObjective "Hire experienced developers";
                node io3: IntermediateObjective "Present ROI analysis to leadership";
                node io4: IntermediateObjective "Partner with existing retailer";
                node io5: IntermediateObjective "Build direct-to-consumer channel";

                // OR junctor for alternative paths
                node or1: OR;
                node or2: OR;

                // Further obstacles blocking intermediate objectives
                node obs4: Obstacle "Training budget limited";
                node obs5: Obstacle "Talent pool is competitive";

                // Obstacles block objectives
                edge obs1 -> obj1: obstacle_blocks_objective;
                edge obs2 -> obj1: obstacle_blocks_objective;
                edge obs3 -> obj1: obstacle_blocks_objective;

                // Alternative ways to overcome skill obstacle
                edge io1 -> or1: intermediate_objective_to_or;
                edge io2 -> or1: intermediate_objective_to_or;
                edge or1 -> obs1: or_to_obstacle;

                // ROI analysis overcomes budget obstacle
                edge io3 -> obs2: intermediate_objective_overcomes_obstacle;

                // Alternative distribution solutions
                edge io4 -> or2: intermediate_objective_to_or;
                edge io5 -> or2: intermediate_objective_to_or;
                edge or2 -> obs3: or_to_obstacle;

                // Recursive obstacles
                edge obs4 -> io1: obstacle_blocks_intermediate_objective;
                edge obs5 -> io2: obstacle_blocks_intermediate_objective;
            }
            """#),
    ExampleGraph(
        name: #"EC — Project Delivery vs Quality"#,
        vgl: #"""
            vgraph projectConflict: EC "Project Delivery vs Quality" {
                // The shared objective both sides agree on
                node obj: CommonObjective "Deliver a successful software product";

                // The two competing needs
                node needA: Need "Meet the market window deadline";
                node needB: Need "Ensure product quality and reliability";

                // The specific wants derived from each need
                node wantA: Want "Release with current feature set now";
                node wantB: Want "Extend timeline for thorough testing";

                // The conflict between the two wants
                node conf: Conflict;

                // Assumptions underlying the conflict
                node assA: Assumption "Testing always requires calendar time";
                node assB: Assumption "Features cannot be descoped";
                node assC: Assumption "Quality requires full manual testing";

                // Solution that breaks the conflict
                node sol: Solution "Implement automated testing pipeline";

                // Objective requires both needs (necessary condition)
                edge obj -> needA: objective_to_need;
                edge obj -> needB: objective_to_need;

                // Needs lead to wants
                edge needA -> wantA: need_to_want;
                edge needB -> wantB: need_to_want;

                // Wants create the conflict
                edge wantA -> conf: want_to_conflict;
                edge wantB -> conf: want_to_conflict;

                // Assumptions exposed
                edge needA -> assA: need_to_assumption;
                edge needB -> assC: need_to_assumption;
                edge conf -> assB: conflict_to_assumption;

                // Solution resolves by breaking assumption
                edge needB -> sol: need_to_solution;
            }
            """#),
    ExampleGraph(
        name: #"TRT — Agile Transformation Implementation"#,
        vgl: #"""
            vgraph agileTransition: TRT "Agile Transformation Implementation" {
                // Given conditions (the context we're working within)
                node g1: Given "Company has 5 development teams";
                node g2: Given "Current waterfall process causes delays";

                // Changeable causes (actions we will take)
                node c1: Changeable "Introduce daily standups";
                node c2: Changeable "Implement CI/CD pipeline";
                node c3: Changeable "Create cross-functional teams";
                node c4: Changeable "Train teams on Scrum practices";

                // Intermediate effects (stepping stones from actions)
                node ie1: IntermediateEffect "Teams communicate more frequently";
                node ie2: IntermediateEffect "Code integration happens daily";
                node ie3: IntermediateEffect "Teams have diverse skillsets";
                node ie4: IntermediateEffect "Teams follow iterative process";
                node ie5: IntermediateEffect "Silos are broken down";
                node ie6: IntermediateEffect "Bugs caught earlier";

                // And junctors for combined conditions
                node and1: AndJunctor;
                node and2: AndJunctor;

                // Desirable effects (the goals we achieve)
                node de1: DesirableEffect "Faster time to market";
                node de2: DesirableEffect "Higher quality releases";
                node de3: DesirableEffect "Better team collaboration";

                // Actions lead to intermediate effects
                edge c1 -> ie1: changeable_causes_intermediate;
                edge c2 -> ie2: changeable_causes_intermediate;
                edge c3 -> ie3: changeable_causes_intermediate;
                edge c4 -> ie4: changeable_causes_intermediate;

                // Given context combines with actions
                edge g1 -> and1: given_to_and_junctor;
                edge ie3 -> and1: intermediate_to_and_junctor;
                edge and1 -> ie5: and_junctor_causes_intermediate;

                // Breaking silos leads to collaboration
                edge ie5 -> de3: intermediate_causes_desirable;

                // Communication helps collaboration too
                edge ie1 -> de3: intermediate_causes_desirable;

                // CI/CD + iterative process combine for quality
                edge ie2 -> and2: intermediate_to_and_junctor;
                edge ie4 -> and2: intermediate_to_and_junctor;
                edge and2 -> ie6: and_junctor_causes_intermediate;

                // Earlier bug detection leads to quality
                edge ie6 -> de2: intermediate_causes_desirable;

                // Quality and collaboration lead to speed
                edge de2 -> de1: desirable_causes_desirable;
                edge de3 -> de1: desirable_causes_desirable;

                // Given waterfall context is addressed by iterative process
                edge g2 -> ie4: given_causes_intermediate;
            }
            """#),
    ExampleGraph(
        name: #"CRT — Sales Decline Analysis"#,
        vgl: #"""
            vgraph salesDecline: CRT "Sales Decline Analysis" {
                // Undesirable Effects (the problems we observe at the top)
                node ude1: UndesirableEffect "Sales revenue declining";
                node ude2: UndesirableEffect "Customer complaints increasing";
                node ude3: UndesirableEffect "Market share decreasing";

                // Intermediate Effects (neutral outcomes in the causal chain)
                node ie1: IntermediateEffect "Customers switching to competitors";
                node ie2: IntermediateEffect "Product perceived as outdated";
                node ie3: IntermediateEffect "Support response time is slow";

                // Desirable Effects (things we want to keep)
                node de1: DesirableEffect "Brand reputation still strong";

                // Given (unchangeable facts at the bottom)
                node g1: Given "Market is highly competitive";
                node g2: Given "Customer expectations keep rising";

                // Changeable (root causes we can address)
                node c1: Changeable "Product development cycle is too long";
                node c2: Changeable "Support team is understaffed";
                node c3: Changeable "No customer feedback loop";

                // And Junctor (multiple conditions required together)
                node and1: AndJunctor;

                // Causal relationships (causes flow upward in CRT)
                // Root causes leading to intermediate effects
                edge c1 -> ie2: changeable_causes_intermediate;
                edge c3 -> ie2: changeable_causes_intermediate;
                edge c2 -> ie3: changeable_causes_intermediate;

                // Given facts contributing to situation
                edge g1 -> ie1: given_causes_intermediate;
                edge g2 -> and1: given_to_and_junctor;
                edge ie2 -> and1: intermediate_to_and_junctor;

                // And junctor combining conditions
                edge and1 -> ie1: and_junctor_causes_intermediate;

                // Alternative causes (implicit OR — any single arrow into ude2 is sufficient)
                edge ie1 -> ude2: intermediate_causes_undesirable;
                edge ie3 -> ude2: intermediate_causes_undesirable;

                // Intermediate effects leading to undesirable effects
                edge ie1 -> ude1: intermediate_causes_undesirable;
                edge ie1 -> ude3: intermediate_causes_undesirable;

                // Brand reputation affected but still positive
                edge ie2 -> de1: intermediate_causes_desirable;
            }
            """#),
    ExampleGraph(
        name: #"ADTree — Data Confidentiality"#,
        vgl: #"""
            vgraph dataConfidentiality: ADTree "Data Confidentiality" {
                node dataConf: Defense "Data Confidentiality"
                node networkSec: Defense "Network Security"
                node physicalSec: Defense "Physical Security"
                node accessControl: Defense "Access Control"
                node firewalls: Defense "Firewalls"
                node passwords: Defense "Passwords"
                node strongPasswords: Defense "Strong Passwords"
                node lock1: Defense "Lock"
                node screening: Defense "Screening"
                node sensitivityTraining: Defense "Sensitivity Training"
                node securityGuard: Defense "Security Guard"
                node videoCameras: Defense "Video Cameras"
                node employeeAttack: Attack "Employee Attack"
                node breakIn: Attack "Break In"
                node corruption: Attack "Corruption"
                node socialEngineering: Attack "Social Engineering"
                node dictionaryAttack: Attack "Dictionary Attack"
                node strongPasswordAttacks: Attack "Strong Password Attacks"
                node findNote: Attack "Find Note"
                node samePasswordDiffAccount: Attack "Same Password, Different Account"
                node backDoor: Attack "Back Door"
                node fireEscape: Attack "Fire Escape"
                node defeatLock: Attack "Defeat Lock"
                node forceOpen: Attack "Force Open"
                node acquireKeys: Attack "Acquire Keys"
                node defeatGuard: Attack "Defeat Guard"
                node bribe: Attack "Bribe"
                node overpower: Attack "Overpower"
                node stealKeys: Attack "Steal Keys"
                node outnumber: Attack "Outnumber"
                node useWeapons: Attack "Use Weapons"
                node andDataConf: AndJunctor
                node andNetworkSec: AndJunctor
                node andOverpower: AndJunctor
                edge networkSec -> andDataConf
                edge physicalSec -> andDataConf
                edge andDataConf -> dataConf
                edge accessControl -> andNetworkSec
                edge firewalls -> andNetworkSec
                edge andNetworkSec -> networkSec
                edge passwords -> accessControl
                edge corruption -> employeeAttack
                edge socialEngineering -> employeeAttack
                edge backDoor -> breakIn
                edge fireEscape -> breakIn
                edge findNote -> strongPasswordAttacks
                edge samePasswordDiffAccount -> strongPasswordAttacks
                edge forceOpen -> defeatLock
                edge acquireKeys -> defeatLock
                edge bribe -> defeatGuard
                edge overpower -> defeatGuard
                edge stealKeys -> defeatGuard
                edge strongPasswords -> dictionaryAttack
                edge lock1 -> backDoor
                edge screening -> corruption
                edge sensitivityTraining -> socialEngineering
                edge securityGuard -> breakIn
                edge videoCameras -> defeatGuard
                edge employeeAttack -> dataConf
                edge breakIn -> physicalSec
                edge dictionaryAttack -> passwords
                edge strongPasswordAttacks -> strongPasswords
                edge defeatLock -> lock1
                edge defeatGuard -> securityGuard
                edge outnumber -> andOverpower
                edge useWeapons -> andOverpower
                edge andOverpower -> overpower
            }
            """#),
    ExampleGraph(
        name: #"GoalTree — Increase Profitability"#,
        vgl: #"""
            vgraph companyStrategy: GoalTree "Increase Profitability" {
                // The single system goal
                node goal: Goal "Make more money, now and in the future";

                // Critical Success Factors (3-5 high-level terminal outcomes)
                node csf1: CriticalSuccessFactor "Maximize Throughput";
                node csf2: CriticalSuccessFactor "Control Operating Expense";
                node csf3: CriticalSuccessFactor "Minimize Inventory and Investment";

                // Necessary Conditions supporting CSF1 (Maximize Throughput)
                node nc1: NecessaryCondition "Maximize sales volume";
                node nc2: NecessaryCondition "Minimize variable costs";
                node nc3: NecessaryCondition "Highly appealing products";

                // Necessary Conditions supporting CSF2 (Control Operating Expense)
                node nc4: NecessaryCondition "Minimize scrap and rework";
                node nc5: NecessaryCondition "Optimize overhead";

                // Necessary Conditions supporting CSF3 (Minimize Inventory)
                node nc6: NecessaryCondition "Optimize outgoing supply chain";
                node nc7: NecessaryCondition "Optimize incoming supply chain";

                // Lower-level NCs (sub-NCs)
                node nc8: NecessaryCondition "Effective market research";
                node nc9: NecessaryCondition "High-quality products";
                node nc10: NecessaryCondition "Robust production process";

                // CSFs support the Goal
                edge csf1 -> goal: csf_to_goal;
                edge csf2 -> goal: csf_to_goal;
                edge csf3 -> goal: csf_to_goal;

                // NCs support CSFs
                edge nc1 -> csf1: nc_to_csf;
                edge nc2 -> csf1: nc_to_csf;
                edge nc3 -> csf1: nc_to_csf;
                edge nc4 -> csf2: nc_to_csf;
                edge nc5 -> csf2: nc_to_csf;
                edge nc6 -> csf3: nc_to_csf;
                edge nc7 -> csf3: nc_to_csf;

                // Sub-NCs support higher NCs
                edge nc8 -> nc1: nc_to_nc;
                edge nc9 -> nc3: nc_to_nc;
                edge nc10 -> nc4: nc_to_nc;
            }
            """#),
    ExampleGraph(
        name: #"IBIS — System Architecture with Folded Modules"#,
        vgl: #"""
            vgraph systemArchitecture: IBIS "System Architecture with Folded Modules" {
                // External entry points
                node q1: Question "How should user requests be handled?";
                node a1: Answer "Use API Gateway pattern";

                // The Authentication module is FOLDED - it will collapse to a single node
                // All internal nodes and edges will be hidden, but connections from outside remain
                folded group authModule "Authentication Module" {
                    node auth1: Question "How to verify identity?";
                    node auth2: Answer "JWT tokens";
                    node auth3: Answer "Session cookies";
                    node auth4: Pro "Stateless, scalable";
                    node auth5: Con "Token size overhead";

                    // Internal edges (will be deleted when folded)
                    edge auth1 -> auth2;
                    edge auth1 -> auth3;
                    edge auth2 -> auth4;
                    edge auth2 -> auth5;

                    // Nested group inside folded group (will also be deleted)
                    group tokenMgmt "Token Management" {
                        node tm1: Question "Token refresh strategy?";
                        node tm2: Answer "Sliding window";
                        edge auth2 -> tm1;
                        edge tm1 -> tm2;
                    };
                };

                // The Database module is also FOLDED
                folded group dbModule "Database Layer" {
                    node db1: Question "Which database?";
                    node db2: Answer "PostgreSQL";
                    node db3: Answer "MongoDB";
                    node db4: Pro "ACID compliance";
                    node db5: Pro "Flexible schema";
                    node db6: Question "Where to host it?";
                    node db7: Answer "Managed cloud service";

                    edge db1 -> db2;
                    edge db1 -> db3;
                    edge db2 -> db4;
                    edge db3 -> db5;
                    edge db6 -> db7;
                };

                // This group is NOT folded - it remains expanded
                group cacheLayer "Cache Layer" {
                    node cache1: Question "Caching strategy?";
                    node cache2: Answer "Redis";
                    node cache3: Pro "Fast in-memory access";

                    edge cache1 -> cache2;
                    edge cache2 -> cache3;
                };

                // External connections - these will be REDIRECTED to the folded group nodes
                edge q1 -> a1;
                edge a1 -> auth1;           // Will redirect to authModule node
                edge a1 -> cache1;          // Stays as-is (cache not folded)
                edge auth2 -> db1;          // Both ends folded - redirects to authModule -> dbModule
                edge cache2 -> db6;         // cache2 stays, db6 redirects to dbModule
            }
            """#),
    ExampleGraph(
        name: #"DecisionTree — Should We Hire This Candidate?"#,
        vgl: #"""
            vgraph hiringDecision: DecisionTree "Should We Hire This Candidate?" {
                node q1: DecisionPoint "Is the candidate technically qualified?";
                node c1: Choice "Yes";
                node c2: Choice "No";
                node q2: DecisionPoint "Does the candidate fit the team culture?";
                node c3: Choice "Yes";
                node c4: Choice "No";
                node o1: Outcome "Extend offer";
                node o2: Outcome "Reject — technical skills insufficient";
                node o3: Outcome "Reject — poor cultural fit";

                edge q1 -> c1: decision_to_choice;
                edge q1 -> c2: decision_to_choice;
                edge c1 -> q2: choice_to_decision;
                edge c2 -> o2: choice_to_outcome;
                edge q2 -> c3: decision_to_choice;
                edge q2 -> c4: decision_to_choice;
                edge c3 -> o1: choice_to_outcome;
                edge c4 -> o3: choice_to_outcome;
            }
            """#),
    ExampleGraph(
        name: #"CLD — Population Dynamics"#,
        vgl: #"""
            vgraph populationCLD: CLD "Population Dynamics" {
                node births: Stock "Births";
                node population: Stock "Population";
                node deaths: Stock "Deaths";
                node foodSupply: Stock "Food Supply";
                node crowding: Stock "Crowding";

                // Reinforcing loop: more births increase population, larger population increases births
                edge births -> population: same;
                edge population -> births: same;

                // Balancing loop: population increases deaths, deaths decrease population
                edge population -> deaths: same;
                edge deaths -> population: opposite;

                // Balancing loop: population reduces food supply, less food reduces births
                edge population -> foodSupply: opposite;
                edge foodSupply -> births: same;

                // Crowding effects
                edge population -> crowding: same;
                edge crowding -> deaths: same;
            }
            """#),
    ExampleGraph(
        name: #"Timeline — 19th Century Europe"#,
        vgl: #"""
            vgraph myTimeline: Timeline "19th Century Europe" {
                node t1800: TimePoint "1800" [alignGroup: "1800"]
                node t1850: TimePoint "1850" [alignGroup: "1850"]
                node t1871: TimePoint "1871" [alignGroup: "1871"]
                edge t1800 -> t1850: sequence
                edge t1850 -> t1871: sequence

                group germany "Germany" {
                    node g1: Event "Napoleon defeats Prussia" [alignGroup: "1800"]
                    node g2: Event "German Unification" [alignGroup: "1871"]
                }
                group england "England" {
                    node e1: Event "Industrial Revolution peaks" [alignGroup: "1850"]
                    node e2: Event "Franco-Prussian War impact" [alignGroup: "1871"]
                }

                edge g1 -> g2: influence "led to"
                edge e1 -> e2: influence
                edge e1 -> g2: influence "industrialization enabled"
            }
            """#),
    ExampleGraph(
        name: #"C4 — Internet Banking System"#,
        vgl: #"""
            // c4model.com's Internet Banking example. The model is unfolded to the code;
            // each view zooms out by folding one node type.
            vgraph banking: C4 "Internet Banking System" {
                node customer: Person "Personal Banking Customer";

                group bigBank: Organisation "Big Bank" {
                    node serviceStaff: Person "Customer Service Staff";
                    node backOfficeStaff: Person "Back Office Staff";
                    node atm: SoftwareSystem "ATM" [backgroundColor: "#8e24aa"];
                    node cbs: SoftwareSystem "Core Banking System" [backgroundColor: "#e8710a"];

                    group ibs: SoftwareSystem "Internet Banking System" {
                        isfolded: false;
                        node staticContent: Container "Static Content";
                        node ui: Container "UI";
                        node statementStore: Database "Statement Store";
                        node database: Database "Database";

                        group backend: Container "Backend" {
                            isfolded: false;
                            node statementApi: Component "Statement API";
                            node signInApi: Component "Sign In API";
                            node accountsSummaryApi: Component "Accounts Summary API";
                            node statementComponent: Component "Statement Component";
                            node securityComponent: Component "Security Component";
                            node emailComponent: Component "Email Component";

                            group adapter: Component "Core Banking System Adapter" {
                                isfolded: false;
                                node adapterInterface: CodeElement "CoreBankingSystemAdapter";
                                node adapterImpl: CodeElement "CoreBankingSystemAdapterImpl";
                                node connection: CodeElement "CoreBankingSystemConnection";
                                node response: CodeElement "Response";
                                node request: CodeElement "Request";
                                node bankAccountsResponse: CodeElement "BankAccountsResponse";
                                node bankAccountsRequest: CodeElement "BankAccountsRequest";
                            };
                        };
                    };
                };

                group aws: Organisation "Amazon Web Services" {
                    node ses: SoftwareSystem "Amazon Web Services Simple Email Service" [backgroundColor: "#c62828"];
                };

                edge customer -> serviceStaff "Asks questions to";
                edge customer -> atm "Withdraws cash using";
                edge serviceStaff -> cbs "Support customers using";
                edge backOfficeStaff -> cbs "Investigate and troubleshoot problems using";
                edge atm -> cbs "Makes transactions using";
                edge ses -> customer "Sends e-mails to";

                // Edges join elements, never boundaries: a detailed node's relationships
                // start at its details, and folding it gathers them onto its box.
                edge customer -> staticContent "Loads the UI from";
                edge customer -> ui "Views account balances and makes payments using";
                edge staticContent -> ui "Delivers";
                edge ui -> statementApi "Requests statements from";
                edge ui -> signInApi "Makes sign in requests to";
                edge ui -> accountsSummaryApi "Requests a list of bank accounts from";

                edge statementApi -> statementComponent "Requests statements from";
                edge statementApi -> securityComponent "Validates authentication token using";
                edge signInApi -> securityComponent "Validates credentials using";
                edge accountsSummaryApi -> securityComponent "Validates authentication token using";
                edge accountsSummaryApi -> adapterInterface "Requests lists of bank accounts from";
                edge statementComponent -> adapterInterface "Requests statement information from";
                edge securityComponent -> emailComponent "Sends emails using";
                edge statementComponent -> statementStore "Reads from and writes to";
                edge securityComponent -> database "Reads from and writes to";
                edge emailComponent -> ses "Sends e-mails to customers using";

                edge adapterImpl -> adapterInterface [arrowhead: "empty"; style: dashed];
                edge adapterImpl -> connection "initialises and pools" [headlabel: "1..20"];
                edge adapterImpl -> bankAccountsRequest "creates";
                edge connection -> response "creates";
                edge connection -> request "executes";
                edge bankAccountsResponse -> response [arrowhead: "empty"; style: dashed];
                edge bankAccountsRequest -> request [arrowhead: "empty"; style: dashed];
                edge connection -> cbs "Makes API requests to";
            }

            vview landscape "System Landscape View" {
                folded node type: SoftwareSystem;
            }

            // The narrower views turn derived edges off: a C4 diagram shows what it shows.
            vview context "System Context View: Internet Banking System" [derivedEdges: false] {
                include group ibs;
                expand 1;
                folded node type: SoftwareSystem;
            }

            vview containers "Container View: Internet Banking System" [derivedEdges: false] {
                include group ibs;
                expand 1;
                folded node type: Container;
            }

            vview components "Component View: Internet Banking System - Backend" [derivedEdges: false] {
                include group backend;
                expand 1;
                folded node type: Component;
            }

            vview code "Code View: Internet Banking System - Backend - Core Banking System Adapter" [derivedEdges: false] {
                include group adapter;
            }
            """#),
    ExampleGraph(
        name: #"Arithmetic — Right and Wrong"#,
        vgl: #"""
            vgraph arithmeticRightAndWrong: Arithmetic "Right and Wrong" {
                node two: Number "2";
                node five: Number "5";
                node eight: Number "8";
                node three: Number "3";
                node four: Number "4";
                node twelve: Number "12";

                node plusOp: Plus;
                node minusOp: Minus;
                node timesOp: Times;
                node divideOp: Divide;

                // Each Equals carries the expected answer as its own label — type
                // into it to set the target. Green when the operator agrees, red
                // showing "computed ≠ expected" when it doesn't.
                node eqPlus: Equals "7";
                node eqMinus: Equals "5";
                node eqTimes: Equals "11";
                node eqDivide: Equals "4";

                // 2 + 5 = 7 — correct, shows "= 7" in green
                edge two -> plusOp: plus_first_operand;
                edge five -> plusOp: plus_second_operand;
                edge plusOp -> eqPlus: plus_result;

                // 8 − 3 = 5 — correct, shows "= 5" in green
                edge eight -> minusOp: minus_first_operand;
                edge three -> minusOp: minus_second_operand;
                edge minusOp -> eqMinus: minus_result;

                // 3 × 4 is 12, but 11 was expected — shows "12 ≠ 11" in red
                edge three -> timesOp: times_first_operand;
                edge four -> timesOp: times_second_operand;
                edge timesOp -> eqTimes: times_result;

                // 12 : 4 is 3, but 4 was expected — shows "3 ≠ 4" in red
                edge twelve -> divideOp: divide_first_operand;
                edge four -> divideOp: divide_second_operand;
                edge divideOp -> eqDivide: divide_result;
            }
            """#),
    ExampleGraph(
        name: #"CLD — Hiding the middle of a chain"#,
        vgl: #"""
            // A view can hide a variable. Overview hides "Stock" and a dotted edge
            // still says Demand and Price are related through it; hover shows the path.
            // Plain hides it too, but turns derived edges off, so the link disappears.
            vgraph shop: CLD "Shop" {
                node demand: Stock "Demand";
                node stock: Stock "Stock";
                node price: Stock "Price";
                edge demand -> stock: same;
                edge stock -> price: opposite;
            }

            vview overview "Overview" {
                exclude node stock;
            }

            vview plain "Plain" [derivedEdges: false] {
                exclude node stock;
            }
            """#),
]
