import minicanvas.MiniCanvas;
import thx.color.Rgbxa;
import thx.color.palettes.Web;
import tink.core.Future;
import glm.Vec2;
import glm.Vec3;
using glm.Vec2;

typedef Point2D = Vec2;
typedef Direction2D = Vec2;

class Shape2D {
    public var vertices:Array<Point2D> = new Array<Point2D>();
    public function new() {}

    public function centre():Point2D {
        var x:Float = 0;
        var y:Float = 0;
        for(vertex in vertices) {
            x += vertex.x;
            y += vertex.y;
        }
        x /= vertices.length;
        y /= vertices.length;
        return new Point2D(x, y);
    }

    public function support(direction:Direction2D):Point2D {
        var d:Float = Math.NEGATIVE_INFINITY;
        var p:Point2D = null;

        for(v in vertices) {
            var dot:Float = Vec2.dot(v, direction);
            if(dot > d) {
                d = dot;
                p = v;
            }
        }

        return p;
    }

    public static function convexHull(verts:Array<Point2D>):Shape2D {
        var ccw:Point2D->Point2D->Point2D->Int = function(p1:Point2D, p2:Point2D, p3:Point2D):Int {
            var area:Float = (p2.x - p1.x)*(p3.y - p1.y) - (p2.y - p1.y)*(p3.x - p1.x);
            if(area > 0) return -1;
            if(area < 0) return 1;
            return 0;
        }

        var startVert:Point2D = null;
        var lowest:Point2D = new Point2D(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
        for(vert in verts) {
            if(vert.y < lowest.y) {
                lowest.y = vert.y;
                lowest.x = vert.x;
                startVert = vert;
            }
            else if(vert.y == lowest.y) {
                if(vert.x < lowest.x) {
                    lowest.y = vert.y;
                    lowest.x = vert.x;
                    startVert = vert;
                }
            }
        }
        verts.sort(function(a:Point2D, b:Point2D):Int {
            var angleA:Float = Math.atan2(a.y - startVert.y, a.x - startVert.x);
            var angleB:Float = Math.atan2(b.y - startVert.y, b.x - startVert.x);
            if(Math.abs(angleA - angleB) <= 0.0000001) return 0;
            if(angleA > angleB) return 1;
            return -1;
        });

        var hull:Array<Point2D> = new Array<Point2D>();
        hull.push(verts[0]);
        hull.push(verts[1]);
        hull.push(verts[2]);

        for(i in 3... verts.length) {
            var top:Point2D = hull.pop();
            while(ccw(hull[hull.length - 1], top, verts[i]) != -1) {
                top = hull.pop();
            }
            hull.push(top);
            hull.push(verts[i]);
        }

        var shape:Shape2D = new Shape2D();
        shape.vertices = hull;
        return shape;
    }

    /**
     *  Calculates the Minkowski Difference of two polygonal shapes
     *  Only used for visualization purposes!
     *  @param a - 
     *  @param b - 
     *  @return Shape2D
     */
    public static function minkowskiDifference(a:Shape2D, b:Shape2D):Shape2D {
        var verts:Array<Point2D> = new Array<Point2D>();
        for(va in a.vertices)
            for(vb in b.vertices)
                verts.push(va - vb);
        return convexHull(verts);
    }
}

class Simplex2D extends Shape2D {
    public var container:Shape2D;
    public var direction:Direction2D;
    public var containsOrigin(default, null):Bool = false;

    public function new(container:Shape2D) {
        super();
        this.container = container;
        direction = new Direction2D(1, 0);
    }

    function cross(a:Vec3, b:Vec3):Vec3 {
        return new Vec3(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        );
    }

    function tripleProduct(a:Vec2, b:Vec2, c:Vec2):Vec2 {
        var A:Vec3 = new Vec3(a.x, a.y, 0);
        var B:Vec3 = new Vec3(b.x, b.y, 0);
        var C:Vec3 = new Vec3(c.x, c.y, 0);

        var first:Vec3 = cross(A, B);
        var second:Vec3 = cross(first, C);

        return new Vec2(second.x, second.y);
    }

    function addSupport():Bool {
        var newVert = container.support(direction);
        vertices.push(newVert);
        return Vec2.dot(newVert, direction) > 0;
    }

    /**
     *  Updates the simplex, and returns false if we cannot contain the origin
     *  @return Bool whether it is possible to contain the origin or not
     */
    public function evolvePastOrigin():Bool {
        switch(vertices.length) {
            case 0: {
                return addSupport();
            }
            case 1: {
                direction *= -1;
                return addSupport();
            }
            case 2: {
                var ab:Direction2D = vertices[1] - vertices[0];
                var a0:Direction2D = vertices[0] * -1;
                direction = tripleProduct(ab, a0, ab);
                return addSupport();
            }
            case 3: {
                var a:Point2D = vertices[2];
                var b:Point2D = vertices[1];
                var c:Point2D = vertices[0];

                var a0:Direction2D = a * -1;
                var ab:Direction2D = b - a;
                var ac:Direction2D = c - a;

                var abPerp:Direction2D = tripleProduct(ac, ab, ab);
                var acPerp:Direction2D = tripleProduct(ab, ac, ac);
                if(abPerp.dot(a0) > 0) {
                    vertices.remove(c);
                    direction = abPerp;
                }
                else if(acPerp.dot(a0) > 0) {
                    vertices.remove(b);
                    direction = acPerp;
                }
                else {
                    containsOrigin = true;
                    return true;
                }

                return addSupport();
            }
            case _: {
                throw 'Can\'t have simplex with ${vertices.length} verts!';
            }
        }
    }
}

enum DemoState {
    NoIntersect;
    IntersectRandomDirection;
    IntersectDifferenceDirection;
}

@await class GJK2D {
    var canvas:MiniCanvas;

    inline function mapX(x:Float):Float {
        return ((x + 20) / (40)) * canvas.width;
    }

    inline function mapY(y:Float):Float {
        return ((y + 20) / 40) * canvas.height;
    }

    function drawDot(x:Float, y:Float, ?colour:Rgbxa):Void {
        if(colour == null) colour = Web.black;
        canvas.dot(mapX(x), mapY(y), 4.0, colour);
    }

    function drawLine(x0:Float, y0:Float, x1:Float, y1:Float, ?colour:Rgbxa):Void {
        if(colour == null) colour = Web.black;
        canvas.line(mapX(x0), mapY(y0), mapX(x1), mapY(y1), 2.0, colour);
    }

    function drawShape(shape:Shape2D, ?colour:Rgbxa):Void {
        if(colour == null) colour = Web.black;
        if(shape.vertices.length > 0)
            drawDot(shape.vertices[0].x, shape.vertices[0].y, colour);
        if(shape.vertices.length > 1)
            drawLine(shape.vertices[0].x, shape.vertices[0].y, shape.vertices[shape.vertices.length - 1].x, shape.vertices[shape.vertices.length - 1].y, colour);
        for(i in 1...shape.vertices.length) {
            drawDot(shape.vertices[i].x, shape.vertices[i].y, colour);
            drawLine(shape.vertices[i - 1].x, shape.vertices[i - 1].y, shape.vertices[i].x, shape.vertices[i].y, colour);
        }
    }

    function drawText(text:String, x:Float, y:Float, ?color:Rgbxa):Void {
        canvas.context(function(ctx, w, h) {
            if(color != null) ctx.fillStyle = (color:String);
            ctx.fillText(text, mapX(x), mapY(y) + 4);
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

    @async public function demo(state:DemoState) {
        while(true) {
            canvas
                .clear()
                .dotGrid(10, 10, 0.5, Web.lightgrey)
                .lineHorizontal(canvas.height / 2 + 0.5, 1.0, Web.black)
                .lineVertical(canvas.width / 2 + 0.5, 1.0, Web.black)
                .context(function(ctx, w, h) {
                    ctx.font = "16px monospace";
                });

            var shapeA:Shape2D = new Shape2D();
            shapeA.vertices.push(new Point2D(-18, -18));
            shapeA.vertices.push(new Point2D(-10, -18));
            shapeA.vertices.push(new Point2D(-10, -13));
            shapeA.vertices.push(new Point2D(-18, -13));

            var shapeB:Shape2D = new Shape2D();
            shapeB.vertices.push(new Point2D(-9, -14));
            shapeB.vertices.push(new Point2D(0, -16));
            shapeB.vertices.push(new Point2D(-7, -8));
            if(state == IntersectDifferenceDirection || state == IntersectRandomDirection) {
                for(vert in shapeB.vertices) {
                    vert.x -= 5;
                }
            }

            var minkowski:Shape2D = Shape2D.minkowskiDifference(shapeA, shapeB);

            @await pause(1.0);
            drawShape(shapeA, Web.red); drawText("shape 1", 2, -18, Web.red);
            @await pause(1.0);
            drawShape(shapeB, Web.orange); drawText("shape 2", 2, -16, Web.orange);
            @await pause(1.0);
            drawShape(minkowski, Web.blue); drawText("minkowski difference", 2, -14, Web.blue);

            var simplex:Simplex2D = new Simplex2D(minkowski);
            simplex.direction = new Direction2D(0, 1);
            if(state == IntersectDifferenceDirection) {
                simplex.direction = shapeB.centre() - shapeA.centre();
            }

            @await pause(1.0);

            var canIntersect:Bool = true;
            do {
                @await pause(1.0);
                canIntersect = simplex.evolvePastOrigin();

                canvas
                    .clear()
                    .dotGrid(10, 10, 0.5, Web.lightgrey)
                    .lineHorizontal(canvas.height / 2 + 0.5, 1.0, Web.black)
                    .lineVertical(canvas.width / 2 + 0.5, 1.0, Web.black);
                drawShape(shapeA, Web.red); drawText("shape 1", 2, -18, Web.red);
                drawShape(shapeB, Web.orange); drawText("shape 2", 2, -16, Web.orange);
                drawShape(minkowski, Web.blue); drawText("minkowski difference", 2, -14, Web.blue);
                drawShape(simplex, Web.green); drawText("simplex", 2, -12, Web.green);
                if(state == IntersectRandomDirection) {
                    drawText("Random initial direction choice", -19.5, 12, Web.blue);
                }
                else if(state == IntersectDifferenceDirection) {
                    drawText("Δ initial direction choice", -19.5, 12, Web.blue);
                }
                if(simplex.containsOrigin) {
                    drawText("Intersection found", -19.5, 14, Web.green);
                }
                else {
                    drawText("No intersection..", -19.5, 14, Web.red);
                }
                if(!canIntersect) {
                    drawText("New support point didn't cross the origin!", -19.5, 16, Web.orangered);
                    drawText("No possible intersection!", -19.5, 18, Web.orangered);
                }
            }
            while(canIntersect && !simplex.containsOrigin);

            @await pause(10.0);
        }
    }
} 