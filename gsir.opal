package opal: import *;
import pygame, math, os;
package random: import randint;
package shutil: import rmtree;

pygame.init();
pygame.font.init();
new list RESOLUTION = ([600, 600]);
new auto screen = (pygame.display.set_mode(RESOLUTION));
pygame.display.set_caption("Visual SIRD model simulator - thatsOven");

if os.path.isdir("graphs") {
    rmtree("graphs");
}
os.mkdir("graphs");

new auto baseTemplate = pygame.image.load("template.png");

new int DISTANCE     = 20,   /* starting distance between people */
        FRAMERATE    = 10, 
        GRAPH_HEIGHT = 512,
        PERSONSIZE   = 6,    
        TA           = 40,   /* infection rate */
        RADIUS       = 20,   /* infection radius */
        TI           = 5,    /* immunization time */
        TM           = 10,   /* mortality rate */
        CHAOS        = 3,    /* maximum quantity of movement of people per iteration */
        QTIMUN       = 0,    /* quantity of immune people at the start of the simulation */
        MUTABILITY   = 5,    /* rate of mutation of the infection */
        MUTATIONQTY  = 1,    /* quantity of mutation per mutation */
        RADIUS_LIMIT = 30;   /* limit of infection radius (used as a check during mutation) */

new bool STATISTICS = True,
         DRAWGRAPHS = True,
         DRAWTEXT   = False;

new list chosenInfectious, people = []; 
chosenInfectious = [randint(0, RESOLUTION[0] // DISTANCE) * DISTANCE, randint(0, RESOLUTION[1] // DISTANCE) * DISTANCE];

new dynamic thisfont;
thisfont = pygame.font.SysFont('Arial', (25 * RESOLUTION[0]) // 800);

new auto clock = pygame.time.Clock();

enum State {
    SUSCEPTIBLE, INFECTIOUS, IMMUNE, DEAD
}

new function drawCross(x, y) {
    pygame.draw.line(screen, (255, 255, 255), (x, y)             , (x + PERSONSIZE, y + PERSONSIZE));
    pygame.draw.line(screen, (255, 255, 255), (x, y + PERSONSIZE), (x + PERSONSIZE, y             ));
}

new list negs;
negs = [
    [-1, -1],
    [ 1, -1],
    [ 1,  1],
    [-1,  1]
];

new float xAngular = math.cos(45),
          yAngular = math.sin(45);

new int imageCount = 0;
new float colorConst = 255 / 100;

new function computeGraphPoints(vals, center) {
    for i = 0; i < 4; i++ {
        vals[i] = [round(center[0] + (negs[i][0] * xAngular * vals[i])), 
                   round(center[1] + (negs[i][1] * yAngular * vals[i]))];
    }
    return vals;
}

new class Infection() {
    new method __init__(infectionRate, infectionRadius, mortalityRate, immunizationTime) {
        this.infectionRate    = infectionRate;
        this.infectionRadius  = infectionRadius;
        this.mortalityRate    = mortalityRate;
        this.immunizationTime = immunizationTime;
    }

    new method copy() {
        return Infection(this.infectionRate, this.infectionRadius, this.mortalityRate, this.immunizationTime);
    }

    new method __iter__() {
        return iter([
            this.infectionRate,
            this.infectionRadius,
            this.mortalityRate,
            this.immunizationTime
        ]);
    }

    new method mutate() {
        useglobal imageCount;

        this.infectionRate    += randint(-MUTATIONQTY, MUTATIONQTY);
        this.infectionRadius  += randint(-MUTATIONQTY, MUTATIONQTY);
        this.mortalityRate    += randint(-MUTATIONQTY, MUTATIONQTY);
        this.immunizationTime += randint(-MUTATIONQTY, MUTATIONQTY);

        if this.infectionRate < 0 {
            this.infectionRate = 0;
        } else {
            if this.infectionRate > 100 {
                this.infectionRate = 100;
            }
        }

        if this.infectionRadius < 0 {
            this.infectionRadius = 0;
        } else {
            if this.infectionRadius > RADIUS_LIMIT {
                this.infectionRadius = RADIUS_LIMIT;
            }
        }

        if this.mortalityRate < 0 {
            this.mortalityRate = 0;
        } else {
            if this.mortalityRate > 100 {
                this.mortalityRate = 100;
            }
        }

        if this.immunizationTime < 1 {
            this.immunizationTime = 1;
        } else {
            if this.immunizationTime > 100 {
                this.immunizationTime = 100;
            }
        }

        if DRAWGRAPHS {
            new auto imageSurface = pygame.Surface((256, 256));
            imageSurface.blit(baseTemplate, (0, 0));
            new list finalColor;
            finalColor = [
                ((round(((this.infectionRate / 100) + (this.infectionRadius / RADIUS_LIMIT)) / 2) * 2) + 255) / 3,
                ((this.immunizationTime * colorConst * 2) + 255) / 3,
                ((this.mortalityRate    * colorConst * 2) + 255) / 3,
            ];

            pygame.draw.polygon(imageSurface, finalColor, computeGraphPoints(list(this), [128, 128]));
            pygame.image.save(imageSurface, os.path.join("graphs", "infection" + str(imageCount) + ".png"));
            imageCount++;
        }
    }
}

new list stateColor;
stateColor = [(0, 255, 0), (255, 0, 0), (0, 0, 255), (255, 255, 255)];

new class Person() {
    new method __init__(x, y, state=State.SUSCEPTIBLE, infection=None) {
        this.x          = x;
        this.y          = y;
        this.state      = state;
        this.immCounter = 0;
        this.infection  = infection;
    }

    new method infectClose() {
        for i = 0; i < len(people); i++ {
            if people[i].x in Utils.tolerance(this.x, this.infection.infectionRadius) and 
               people[i].y in Utils.tolerance(this.y, this.infection.infectionRadius) {
                if people[i].state == State.SUSCEPTIBLE and randint(0, 100) < this.infection.infectionRate {
                    people[i].state     = State.INFECTIOUS;
                    people[i].infection = this.infection.copy();

                    if randint(0, 100) < MUTABILITY {
                        people[i].infection.mutate();
                    }
                }
            }
        }
    }

    new method show() {
        if this.state != State.DEAD {
            this.x += randint(-CHAOS, CHAOS);
            this.y += randint(-CHAOS, CHAOS);

            if this.x <= 0 {
                this.x = CHAOS + PERSONSIZE;
            } else {
                if this.x >= RESOLUTION[0] {
                    this.x = RESOLUTION[0] - CHAOS - PERSONSIZE;
                }
            }

            if this.y <= 0 {
                this.y = CHAOS + PERSONSIZE;
            } else {
                if this.y >= RESOLUTION[1] {
                    this.y = RESOLUTION[1] - CHAOS - PERSONSIZE;
                }
            }
        }
        
        if this.infection is not None {
            if this.immCounter >= this.infection.immunizationTime {
                if randint(0, 100) < this.infection.mortalityRate {
                    this.state = State.DEAD;
                } else {
                    this.state = State.IMMUNE;
                }
                this.immCounter = 0;
                this.infection  = None;
            }
        }
        
        match this.state {
            case State.SUSCEPTIBLE {
                pygame.draw.rect(screen, stateColor[this.state], (this.x - (PERSONSIZE // 2), this.y - (PERSONSIZE // 2), PERSONSIZE, PERSONSIZE));
            }
            case State.INFECTIOUS {
                this.infectClose();
                this.immCounter++;
                pygame.draw.rect(screen, stateColor[this.state], (this.x - (PERSONSIZE // 2), this.y - (PERSONSIZE // 2), PERSONSIZE, PERSONSIZE));
            }
            case State.IMMUNE {
                pygame.draw.rect(screen, stateColor[this.state], (this.x - (PERSONSIZE // 2), this.y - (PERSONSIZE // 2), PERSONSIZE, PERSONSIZE));
            }
            case State.DEAD {
                drawCross(this.x, this.y);
            }
        }
    }
}

new function countStates() {
    new <Array> SIRD = Array(4, int);
    for i = 0; i < len(people); i++ {
        SIRD[people[i].state]++;
    }
    return SIRD;
}

new int populationQty = 0;
for y = DISTANCE; y < RESOLUTION[1]; y += DISTANCE {
    for x = DISTANCE; x < RESOLUTION[0]; x += DISTANCE {
        if [x, y] != chosenInfectious {
            if randint(0, 100) < QTIMUN {
                people.append(Person(x, y, State.IMMUNE));
            } else {
                people.append(Person(x, y));
            }
        } else {
            people.append(Person(x, y, State.INFECTIOUS, Infection(TA, RADIUS, TM, TI)));
        }
        populationQty++;
    }
}


new dynamic textsurface, offsetsurface;
new <Array> counts;
new list stats = [];
new str text;
new bool loop = True;

while True {
    clock.tick(FRAMERATE);

    for i = 0; i < len(people); i++ {
        people[i].show();
    }

    if STATISTICS {
        counts = countStates();
        stats.append(counts);

        if DRAWTEXT {
            text = "Susceptibles = {}, Infectious = {}, Immunes = {}, Deads = {}".format(counts[0], counts[1], counts[2], counts[3]);
            textsurface   = thisfont.render(text, True, (255, 255, 255));
            offsetsurface = thisfont.render(text, True, (0,   0,   0  ));
            screen.blit(offsetsurface, (4, 3));
            screen.blit(textsurface,   (1, 0));
        }
    }

    for event in pygame.event.get() {
        if event.type == pygame.QUIT { 
            loop = False;
            break;
        }
    }

    if not loop { break;}

    pygame.display.update();
    screen.fill((0, 0, 0));
}

if STATISTICS {
    new float drawConst   = GRAPH_HEIGHT / populationQty;
    new int finalXRes     = len(stats);

    new auto graphSurface = pygame.Surface((finalXRes, GRAPH_HEIGHT));
    graphSurface.fill((0, 0, 0));

    new int y, val;

    for x = 0; x < finalXRes; x++ {
        y = GRAPH_HEIGHT;
        for i = 0; i < 4; i++ {
            val = round(stats[x][i] * drawConst);
            pygame.draw.line(graphSurface, stateColor[i], (x, y), (x, (y - val if y - val >= 0 else 0)));
            y -= val;
        }
        if y > 0 {
            pygame.draw.line(graphSurface, stateColor[3], (x, y), (x, 0));
        }
    }
    pygame.image.save(graphSurface, "stats.png");
}
