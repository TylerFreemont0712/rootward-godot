"""Fine-detail V4-family guides for the two quality-check renders."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent / "quality-comparison" / "guides"
OUT.mkdir(parents=True, exist_ok=True)

def draw(name, size, workshop=False):
    w, h = size
    im = Image.new("L", size, 0)
    d = ImageDraw.Draw(im)
    q = lambda x, y: (round(x*w), round(y*h))
    def line(points, width=4): d.line([q(x,y) for x,y in points], fill=255, width=width, joint="curve")
    def rect(box, width=4): d.rectangle(tuple(round(v*(w if i%2==0 else h)) for i,v in enumerate(box)), outline=255, width=width)
    # Fixed V4 geometry: a rear apex at top-center, ridge returning to the front gable,
    # and two roof planes expanding toward the front eaves. No side plane is drawn.
    line([(.50,.045),(.95,.52),(.91,.60),(.09,.60),(.05,.52),(.50,.045)], 8)
    line([(.50,.045),(.50,.585)], 6)
    # Broken, staggered shingle clusters follow the two roof planes instead of broad bands.
    for row, y in enumerate((.15,.25,.35,.45,.54)):
        s=(y-.045)/(.52-.045)
        left=.50-.45*s; right=.50+.45*s
        for i in range(5):
            x0=left+(right-left)*i/5
            x1=left+(right-left)*(i+1)/5
            ym=y+(.018 if (row+i)%2 else 0)
            line([(x0,ym),(x1,ym+.012)],3)
        # Short seams run toward the eaves, broken between staggered rows.
        for i in range(1,5):
            x=left+(right-left)*i/5
            line([(x,y-.025),(x-.008,y+.028)],3)
    # Flat south/front façade, carefully bounded stone footing, no side wall.
    left,right=(.08,.92) if workshop else (.15,.85)
    line([(left,.575),(right,.575),(right,.94),(left,.94),(left,.575)],8)
    line([(left,.875),(right,.875)],6)
    for x in ((.11,.19,.28,.72,.81,.89) if workshop else (.205,.28,.355,.645,.72,.795)):
        line([(x,.89),(x,.94)],3)
    # Timber courses with staggered joins give the model texture cues without stripe-sized regions.
    for y in (.64,.70,.76,.82):
        line([(left+.02,y),(right-.02,y)],3)
    for y, xs in ((.65,(.31,.57)),(.71,(.23,.49,.70)),(.77,(.37,.62)),(.83,(.26,.53,.76))):
        for x in xs: line([(x,y),(x,y+.045)],3)
    if workshop:
        # Wide working doors remain centered; tools and forge vent are façade details.
        rect((.22,.64,.78,.94),7); line([(.50,.65),(.50,.93)],5)
        for x in (.15,.85):
            line([(x,.69),(x,.82)],5); line([(x-.035,.71),(x+.035,.71)],5)
            line([(x-.025,.80),(x+.025,.80)],4)
        rect((.42,.585,.58,.625),5)
    else:
        # Centered arch and two balanced windows echo the V4 home.
        rect((.25,.655,.36,.745),5); line([(.305,.66),(.305,.74)],3)
        rect((.64,.655,.75,.745),5); line([(.695,.66),(.695,.74)],3)
        d.arc(tuple(round(v*(w if i%2==0 else h)) for i,v in enumerate((.385,.715,.615,.945))),180,360,fill=255,width=7)
        line([(.385,.83),(.385,.94),(.615,.94),(.615,.83)],7)
        line([(.50,.79),(.50,.94)],4)
        # Rear chimney sits behind the roof ridge and does not reveal a side elevation.
        rect((.72,.12,.81,.30),6)
        line([(.72,.17),(.81,.17)],3)
    im.save(OUT / name)

draw("home-v4-detail.png", (1024,1024))
draw("workshop-v4-detail.png", (1152,960), workshop=True)
