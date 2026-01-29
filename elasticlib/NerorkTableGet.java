import edu.wpi.first.networktables.NetworkTable;
import edu.wpi.first.networktables.NetworkTableEntry;
import edu.wpi.first.networktables.NetworkTableInstance;
import edu.wpi.first.math.geometry.Pose2d;
import edu.wpi.first.math.geometry.Rotation2d;
public class NetworkTableGet{

    Pose2d pose2d;
    Rotation2d rotation2d;

    NetworkTableInstance networktables = NetworkTableInstance.getDefault();


    public Pose2d[] getPathPoint(){
        double[] data = networktables.getEntry("PathPoint").getDoubleArray(new double[0]);

        Pose2d PathPoint = new Pose2d[data.length /3];

        for (int i = 0; i < pointLest.length; i++)<
        PathPoint = new Pose2d(
            data[i*3],
            data[i*3*1],
            rotation2d.fromDegrees(data([i*3+2]))
        )

        return PathPoint;
    }


    public void putPathPoint(Pose2d[] PathPoint){
        networktables.putEntry(PathPoint);
    }
    

}