import minicanvas.MiniCanvas;
import thx.color.Rgbxa;
import thx.color.palettes.Web;
import tink.core.Future;

typedef Point1D = Float;
typedef Direction1D = Float;

class Shape1DIterator {
    var line:Shape1D;
    var i:Int;

    public function new(line:Shape1D) {
        this.line = line;
        i = 0;
    }

    public function hasNext() {
        return i < 2;
    }

    public function next() {
        var p:Point1D =  switch(i) {
            case 0: line.a;
            case _: line.b;
        }
        i++;
        return p;
    }
}

class Shape1D {
    public var a:Point1D;
    public var b:Point1D;

    public function new(a:Point1D, b:Point1D) {
        this.a = a;
        this.b = b;
    }

    public function points():Shape1DIterator {
        return new Shape1DIterator(this);
    }
}

class Simplex {
    public var points:Array<Point1D> = new Array<Point1D>();

    public function new() {}

    public function centre():Point1D {
        return (points[0] + points[1]) / 2.0;
    }
    
    public function coversOrigin():Bool {
        return switch(points.length) {
            case 1: false;
            case 2: {
                points[0] <= 0 && points[1] >= 0 || points[0] >= 0 && points[1]<= 0;
            }
            case _: false;
        }
    }
}

@await class GJK1D {
    var canvas:MiniCanvas;

    inline function map(x:Float):Float {
        return ((x + 20) / (40)) * canvas.width;
    }

    function drawDot(x:Float, y:Float, ?colour:Rgbxa):Void {
        if(colour == null) colour = Web.black;
        canvas.dot(map(x), y, 4.0, colour);
    }

    function drawShape1D(line:Shape1D, y:Float, ?colour:Rgbxa):Void {
        if(colour == null) colour = Web.black;
        drawDot(line.a, y, colour);
        canvas.line(map(line.a), y, map(line.b), y, 2.0, colour);
        drawDot(line.b, y, colour);
    }

    function drawText(text:String, x:Float, y:Float, ?color:Rgbxa):Void {
        canvas.context(function(ctx, w, h) {
            if(color != null) ctx.fillStyle = (color:String);
            ctx.fillText(text, map(x), y + 4);
        });
    }

    function pause(t:Float):Future<Float> {
        var trigger:FutureTrigger<Float> = new FutureTrigger<Float>();
        haxe.Timer.delay(function() trigger.trigger(t), Std.int(t * 1000.0));
        return trigger.asFuture();
    }

    public function new(canvas:MiniCanvas, name:String) {
        this.canvas = canvas;
        canvas.display(name);
    }

    function minkowskiDifference(lineA:Shape1D, lineB:Shape1D):Shape1D {
        // calculate the minkowski difference for every point
        var points:Array<Float> = [
            lineA.a - lineB.a,
            lineA.a - lineB.b,
            lineA.b - lineB.a,
            lineA.b - lineB.b
        ];

        // calculate the convex hull of the shape
        var result:Shape1D = new Shape1D(Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY);
        for(point in points) {
            if(point < result.a) result.a = point;
            if(point > result.b) result.b = point;
        }
        return result;
    }

    function support(a:Shape1D, b:Shape1D, dir:Direction1D):Float {
        function furthestInDir(line:Shape1D, dir:Direction1D):Float {
            var furthest:Float = Math.NEGATIVE_INFINITY;
            var furthestPoint1D:Point1D = 0;
            for(point in line.points()) {
                var test:Float = point * dir; // dot product
                if(test > furthest) {
                    furthest = test;
                    furthestPoint1D = point;
                }
            }
            return furthestPoint1D;
        }

        var pa:Float = furthestInDir(a, dir);
        var pb:Float = furthestInDir(b, -dir);
        var pc:Float = pa - pb;
        return pc;
    }

    @async public function demo(intersect:Bool) {
        while(true) {
            canvas
                .clear()
                .dotGrid(10, 10, 0.5, Web.lightgrey)
                .lineVertical(canvas.width / 2 + 0.5, 1.0, Web.black)
                .context(function(ctx, w, h) {
                    ctx.font = "16px monospace";
                });
            var y:Float = 10;
            var lineA:Shape1D = new Shape1D(-6, intersect ? -2 : 2);
            var lineB:Shape1D = new Shape1D(intersect ? 1 : -2, 5);

            @await pause(1.0);
            drawShape1D(lineA, y, Web.red); drawText("line 1", lineA.b + 1, y); y += 20;
            @await pause(1.0);
            drawShape1D(lineB, y, Web.orange); drawText("line 2", lineB.b + 1, y); y += 20;

            @await pause(1.0);
            var m:Shape1D = minkowskiDifference(lineA, lineB);
            drawShape1D(m, y, Web.blue); drawText("minkowski difference", m.b + 1, y); y += 20;

            @await pause(3.0);
            drawText("supports:", -20, y, Web.green); y += 20;
            var supports:Array<Float> = new Array<Float>();
            supports.push(support(lineA, lineB, 1));
            supports.push(support(lineA, lineB, -1));
            var sName:String = "a";
            for(point in supports) {
                drawDot(point, y, Web.green); drawText(sName, point + 1, y);
                sName = String.fromCharCode(sName.charCodeAt(0) + 1);
                @await pause(1.0);
            }
            y += 20;

            @await pause(1.0);
            var simplex:Simplex = new Simplex();
            simplex.points = supports;
            //drawText(simplex.coversOrigin() ? "intersecting!" : "no intersection", simplex.centre(), y, Web.black);
            if(simplex.coversOrigin()) {
                drawText("simplex covers origin", -20, y, Web.black); y += 20;
                drawText(" -> intersection detected!", -20, y, Web.green);
            }
            else {
                drawText("simplex doesn't cover origin", -20, y, Web.black); y += 20;
                drawText(" -> no intersection!", -20, y, Web.green);
            }

            @await pause(5.0);
        }
    }
} 