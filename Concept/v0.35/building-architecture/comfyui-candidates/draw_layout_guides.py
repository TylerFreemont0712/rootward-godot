"""Draw V4-family lineart control guides; these are structural inputs, never output art."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent / "lineart-guides"
OUT.mkdir(parents=True, exist_ok=True)
WHITE = 255


def line(draw, points, width=7):
    draw.line(points, fill=WHITE, width=width, joint="curve")


def home(size=(1024, 1024)):
    w, h = size
    im = Image.new("L", size, 0); d = ImageDraw.Draw(im)
    # V4 camera family: the ridge recedes to the top; only the broad south/front plane is visible.
    roof = [(w*.50,h*.055),(w*.96,h*.54),(w*.91,h*.61),(w*.09,h*.61),(w*.04,h*.54),(w*.50,h*.055)]
    line(d, roof, 10)
    line(d, [(w*.50,h*.055),(w*.50,h*.59)], 7)
    # Receding slate courses on both roof planes.
    for t in range(1,8):
        y=h*(.10+t*.065); side=(y-h*.055)/(h*.54-h*.055)
        lx=w*(.50-.46*side); rx=w*(.50+.46*side)
        line(d,[(lx,y),(rx,y)],4)
    # Flat front wall, stone base, two front windows, arched doorway.
    line(d,[(w*.16,h*.57),(w*.84,h*.57),(w*.84,h*.94),(w*.16,h*.94),(w*.16,h*.57)],9)
    line(d,[(w*.16,h*.88),(w*.84,h*.88)],7)
    for x in (.30,.70):
        d.rectangle((w*(x-.055),h*.66,w*(x+.055),h*.74),outline=WHITE,width=7)
        line(d,[(w*x,h*.66),(w*x,h*.74)],4)
    box=(w*.39,h*.72,w*.61,h*.94)
    d.arc(box,start=180,end=360,fill=WHITE,width=9)
    line(d,[(w*.39,h*.83),(w*.39,h*.94),(w*.61,h*.94),(w*.61,h*.83)],9)
    line(d,[(w*.50,h*.79),(w*.50,h*.94)],5)
    # Short chimney behind the ridge.
    d.rectangle((w*.70,h*.13,w*.81,h*.32),outline=WHITE,width=8)
    line(d,[(w*.70,h*.18),(w*.81,h*.18)],5)
    return im


def workshop(size=(1152,1024)):
    w,h=size
    im=Image.new("L",size,0); d=ImageDraw.Draw(im)
    # A broad, low roof footprint keeps the roof depth behind the front facade without exposing a side wall.
    roof=[(w*.25,h*.07),(w*.75,h*.07),(w*.95,h*.58),(w*.05,h*.58),(w*.25,h*.07)]
    line(d,roof,10)
    line(d,[(w*.50,h*.07),(w*.50,h*.58)],7)
    for t in range(1,8):
        y=h*(.11+t*.062); s=(y-h*.07)/(h*.51)
        lx=w*(.25-.20*s); rx=w*(.75+.20*s)
        line(d,[(lx,y),(rx,y)],4)
    # Wide, flat facade and broad workshop entrance; no side geometry.
    line(d,[(w*.08,h*.56),(w*.92,h*.56),(w*.92,h*.94),(w*.08,h*.94),(w*.08,h*.56)],9)
    line(d,[(w*.08,h*.88),(w*.92,h*.88)],7)
    door=(w*.27,h*.64,w*.73,h*.94)
    d.rectangle(door,outline=WHITE,width=9)
    line(d,[(w*.50,h*.64),(w*.50,h*.94)],7)
    # Front-mounted tools, readable as details but subordinate to the doorway.
    for x in (.17,.83):
        line(d,[(w*x,h*.68),(w*x,h*.82)],7)
        line(d,[(w*(x-.035),h*.70),(w*(x+.035),h*.70)],7)
        line(d,[(w*(x-.035),h*.81),(w*(x+.035),h*.81)],7)
    # A single front loft window and rear chimney keep it recognizably a workshop.
    d.rectangle((w*.45,h*.57,w*.55,h*.62),outline=WHITE,width=6)
    d.rectangle((w*.77,h*.13,w*.86,h*.28),outline=WHITE,width=7)
    return im

for name,im in (("home-v4-lineart.png",home()),("workshop-v4-lineart.png",workshop())):
    im.save(OUT/name)
    print(name,im.size)
