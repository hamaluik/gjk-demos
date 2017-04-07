import minicanvas.MiniCanvas;

class Main {
    public static function main() {
        var d1_a:GJK1D = new GJK1D(MiniCanvas.create(401, 141), "1D No Intersection");
        d1_a.demo(false);

        var d1_2:GJK1D = new GJK1D(MiniCanvas.create(401, 141), "1D Intersection");
        d1_2.demo(true);

        var d2_a:GJK2D = new GJK2D(MiniCanvas.create(401, 401), "2D No Intersection");
        d2_a.demo(GJK2D.DemoState.NoIntersect);

        var d2_b:GJK2D = new GJK2D(MiniCanvas.create(401, 401), "2D Intersection, bad choice of initial intersection");
        d2_b.demo(GJK2D.DemoState.IntersectRandomDirection);

        var d2_c:GJK2D = new GJK2D(MiniCanvas.create(401, 401), "2D Intersection");
        d2_c.demo(GJK2D.DemoState.IntersectDifferenceDirection);
    }
}