package opal: import *;
package random: import randint;
package shutil: import rmtree;
import math, os, pygame;

new <Vector> RESOLUTION = Vector(600, 600);

        # starting distance between people
new int DISTANCE     = 20,
        FRAMERATE    = 10,
        GRAPH_HEIGHT = 512,
        PERSONSIZE   = 6,
        # infection rate
        TA           = 40,
        # infection radius
        RADIUS       = 20,
        # immunization time
        TI           = 5,
        # mortality rate
        TM           = 10,
        # maximum quantity of movement of people per iteration
        CHAOS        = 3,
        # quantity of immune people at the start of the simulation
        QTIMUN       = 0,
        # rate of mutation of the infection
        MUTABILITY   = 5,
        # quantity of mutation per mutation
        MUTATIONQTY  = 1,
        # limit of infection radius (used as a check during mutation)
        RADIUS_LIMIT = 30;

new bool STATISTICS = True,
         DRAWGRAPHS = True,
         DRAWTEXT   = False;

new int CENTER_TMP = 128;
new float COLOR_CONST = 255 / 100;
new <Vector> PERSON_DIM = Vector(PERSONSIZE, PERSONSIZE);

new <Graphics> graphics;
graphics = Graphics(RESOLUTION, FRAMERATE, caption = "Visual SIRD model simulator - thatsOven", fontSize = (25 * RESOLUTION.x) // 800);

new auto baseTemplate = graphics.loadImage(os.path.join(HOME_DIR, "template.png"));

new list people, stats;

new class Infection {
    new int imageCount = 0;
    new tuple negs;
    negs = (
        Vector(-1, -1),
        Vector( 1, -1),
        Vector( 1,  1),
        Vector(-1,  1)
    );

    new float xAngular = math.cos(45),
              yAngular = math.sin(45);

    new method __init__(rate, radius, mortality, duration) {
        this.rate      = rate;
        this.radius    = radius;
        this.mortality = mortality;
        this.duration  = duration;
    }

    new method copy() {
        return Infection(this.rate, this.radius, this.mortality, this.duration);
    }

    new method __iter__() {
        return iter((
            this.rate,
            this.radius,
            this.mortality,
            this.duration
        ));
    }

    new method __computeGraphPoints() {
        new list vals = list(this);

        for i in range(4) {
            vals[i] = [round(CENTER_TMP + (Infection.negs[i].x * Infection.xAngular * vals[i])),
                       round(CENTER_TMP + (Infection.negs[i].y * Infection.yAngular * vals[i]))];
        }

        return vals;
    }

    new method mutate() {
        this.rate      += randint(-MUTATIONQTY, MUTATIONQTY);
        this.radius    += randint(-MUTATIONQTY, MUTATIONQTY);
        this.mortality += randint(-MUTATIONQTY, MUTATIONQTY);
        this.duration  += randint(-MUTATIONQTY, MUTATIONQTY);

        this.rate      = Utils.limitToRange(this.rate,      0, 100);
        this.radius    = Utils.limitToRange(this.radius,    0, RADIUS_LIMIT);
        this.mortality = Utils.limitToRange(this.mortality, 0, 100);
        this.duration  = Utils.limitToRange(this.duration,  0, 100);

        if DRAWGRAPHS {
            new auto imgSurf = pygame.Surface((256, 256));
            imgSurf.blit(baseTemplate, (0, 0));

            new dynamic color;
            color = [
                ((round(((this.rate / 100) + (this.radius / RADIUS_LIMIT))) * 2) + 255) / 3,
                ((this.duration  * COLOR_CONST * 2) + 255) / 3,
                ((this.mortality * COLOR_CONST * 2) + 255) / 3,
            ];

            pygame.draw.polygon(imgSurf, color, this.__computeGraphPoints());
            pygame.image.save(imgSurf, os.path.join(HOME_DIR, "graphs", "infection" + str(Infection.imageCount) + ".png"));
            Infection.imageCount++;
        }
    }
}

enum States {
    SUSCEPTIBLE, INFECTIOUS, IMMUNE, DEAD
}

new class Person {
    new tuple stateColor;
    stateColor = (
        (  0, 255,   0),
        (255,   0,   0),
        (  0,   0, 255),
        (255, 255, 255)
    );

    new method __init__(pos, state = States.SUSCEPTIBLE, infection = None) {
        this.pos       = pos;
        this.state     = state;
        this.infection = infection;
        this.time      = 0;
    }

    new method infect() {
        for i in range(len(people)) {
            if people[i].pos.x in Utils.tolerance(this.pos.x, this.infection.radius) and
               people[i].pos.y in Utils.tolerance(this.pos.y, this.infection.radius) {
                if people[i].state == States.SUSCEPTIBLE and randint(0, 100) < this.infection.rate {
                    people[i].state     = States.INFECTIOUS;
                    people[i].infection = this.infection.copy();

                    if randint(0, 100) < MUTABILITY {
                        people[i].infection.mutate();
                    }
                }
            }
        }
    }

    new method __cross() {
        graphics.line(this.pos, this.pos + PERSONSIZE);
        graphics.line(
            Vector(this.pos.x, this.pos.y + PERSONSIZE),
            Vector(this.pos.x + PERSONSIZE, this.pos.y)
        );
    }

    new method update() {
        if this.state != States.DEAD {
            this.pos.x += randint(-CHAOS, CHAOS);
            this.pos.y += randint(-CHAOS, CHAOS);

            this.pos.x = Utils.limitToRange(this.pos.x, 0, RESOLUTION.x);
            this.pos.y = Utils.limitToRange(this.pos.y, 0, RESOLUTION.y);
        }

        if this.infection is not None {
            if this.time >= this.infection.duration {
                if randint(0, 100) < this.infection.mortality {
                    this.state = States.DEAD;
                } else {
                    this.state = States.IMMUNE;
                }

                this.time      = 0;
                this.infection = None;
            }
        }

        if this.state == States.INFECTIOUS {
            this.infect();
            this.time++;
        }

        if this.state == States.DEAD {
            this.__cross();
        } else {
            new dynamic drawVec = this.pos.getIntCoords() - (PERSONSIZE // 2);
            graphics.fastRectangle(drawVec, PERSON_DIM, Person.stateColor[this.state]);
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

@graphics.event(QUIT);
new function __quit(event) {
    if STATISTICS {
        new float drawConst = GRAPH_HEIGHT / qty;
        new int finalXRes   = len(stats);

        new auto surf = pygame.Surface((finalXRes, GRAPH_HEIGHT));
        surf.fill((0, 0, 0));

        new int y, val;

        for x in range(finalXRes) {
            y = GRAPH_HEIGHT;

            for i in range(4) {
                val = round(stats[x][i] * drawConst);

                pygame.draw.line(
                    surf, Person.stateColor[i],
                    (x, y), (x, (y - val if y - val >= 0 else 0))
                );

                y -= val;
            }

            if y > 0 {
                pygame.draw.line(surf, Person.stateColor[3], (x, y), (x, 0));
            }
        }

        pygame.image.save(surf, os.path.join(HOME_DIR, "stats.png"));
    }

    quit;
}

@graphics.update;
new function update() {
    global stats;

    for person in people {
        person.update();
    }

    if STATISTICS {
        new dynamic counts = countStates();
        stats.append(counts);

        if DRAWTEXT {
            graphics.drawOutlineText(
                [f"Susceptibles = {counts[0]}, Infectious = {counts[1]}, Immunes = {counts[2]}, Deads = {counts[3]}"],
                Vector(1)
            );
        }
    }
}

main {
    new auto dir = os.path.join(HOME_DIR, "graphs");

    if os.path.isdir(dir) {
        rmtree(dir);
    }

    os.mkdir(dir);

    stats  = [];
    people = [];

    new tuple chosen;
    chosen = (
        randint(0, RESOLUTION.x // DISTANCE) * DISTANCE,
        randint(0, RESOLUTION.y // DISTANCE) * DISTANCE
    );

    new int qty = 0;
    for y = DISTANCE; y < RESOLUTION.y; y += DISTANCE {
        for x = DISTANCE; x < RESOLUTION.x; x += DISTANCE, qty++ {
            if (x, y) != chosen {
                if randint(0, 100) < QTIMUN {
                    people.append(Person(Vector(x, y), States.IMMUNE));
                } else {
                    people.append(Person(Vector(x, y)));
                }
            } else {
                people.append(Person(Vector(x, y), States.INFECTIOUS, Infection(TA, RADIUS, TM, TI)));
            }
        }
    }

    graphics.run(handleQuit = False);
}
