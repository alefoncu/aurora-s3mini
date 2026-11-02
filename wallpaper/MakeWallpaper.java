import java.awt.*;
import java.awt.geom.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.File;
import java.util.Random;

/** "Aurora" wallpaper: layered radial glows on a deep ink base, lightly dithered to avoid banding. */
public class MakeWallpaper {
    static final int W = 480, H = 800;

    static void blob(Graphics2D g, double cx, double cy, double r, int rgb, float a) {
        Color c = new Color(rgb);
        Color c0 = new Color(c.getRed(), c.getGreen(), c.getBlue(), (int) (255 * a));
        Color c1 = new Color(c.getRed(), c.getGreen(), c.getBlue(), 0);
        g.setPaint(new RadialGradientPaint(new Point2D.Double(cx, cy), (float) r, new float[]{0f, 1f}, new Color[]{c0, c1}));
        g.fill(new Rectangle(0, 0, W, H));
    }

    public static void main(String[] a) throws Exception {
        BufferedImage im = new BufferedImage(W, H, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = im.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setPaint(new GradientPaint(0, 0, new Color(0x141046), 0, H, new Color(0x0B0D2A)));
        g.fillRect(0, 0, W, H);
        blob(g, 40, 120, 520, 0x3B82F6, 0.80f);
        blob(g, 330, 400, 460, 0x7C3AED, 0.78f);
        blob(g, 470, 760, 470, 0xF472B6, 0.72f);
        blob(g, 70, 700, 300, 0xFB7185, 0.34f);
        blob(g, 400, 60, 240, 0x22D3EE, 0.22f);
        g.dispose();
        Random rnd = new Random(7);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int p = im.getRGB(x, y);
            int n = rnd.nextInt(5) - 2;
            int r = Math.max(0, Math.min(255, ((p >> 16) & 255) + n));
            int gr = Math.max(0, Math.min(255, ((p >> 8) & 255) + n));
            int b = Math.max(0, Math.min(255, (p & 255) + n));
            im.setRGB(x, y, (r << 16) | (gr << 8) | b);
        }
        ImageIO.write(im, "png", new File(a[0]));
    }
}
