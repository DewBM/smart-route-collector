namespace backend.Services;

public class RouteService
{
    private const double EarthRadiusKm = 6371;

    public double Haversine(double lat1, double lon1, double lat2, double lon2)
    {
        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);

        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusKm * c;
    }

    public List<int> GetOptimalRoute(int startNodeId, List<(int Id, double Lat, double Lon)> nodes)
    {
        var distances = nodes.ToDictionary(n => n.Id, _ => double.MaxValue);
        var previous = new Dictionary<int, int?>();
        var unvisited = nodes.Select(n => n.Id).ToHashSet();

        distances[startNodeId] = 0;

        foreach (var node in nodes)
            previous[node.Id] = null;

        while (unvisited.Count > 0)
        {
            var current = unvisited
                .OrderBy(id => distances[id])
                .First();

            unvisited.Remove(current);

            var currentNode = nodes.First(n => n.Id == current);

            foreach (var neighborId in unvisited)
            {
                var neighbor = nodes.First(n => n.Id == neighborId);
                var weight = Haversine(currentNode.Lat, currentNode.Lon, neighbor.Lat, neighbor.Lon);
                var newDist = distances[current] + weight;

                if (newDist < distances[neighborId])
                {
                    distances[neighborId] = newDist;
                    previous[neighborId] = current;
                }
            }
        }

        return ReconstructPath(startNodeId, nodes, previous);
    }

    private List<int> ReconstructPath(int startNodeId, List<(int Id, double Lat, double Lon)> nodes, Dictionary<int, int?> previous)
    {
        var supplierIds = nodes
            .Where(n => n.Id != startNodeId)
            .Select(n => n.Id)
            .ToList();

        var ordered = new List<int>();
        var remaining = supplierIds.ToHashSet();
        var current = startNodeId;

        while (remaining.Count > 0)
        {
            var next = remaining
                .OrderBy(id => previous[id] == current ? 0 : 1)
                .ThenBy(id =>
                {
                    var currentNode = nodes.First(n => n.Id == current);
                    var neighbor = nodes.First(n => n.Id == id);
                    return Haversine(currentNode.Lat, currentNode.Lon, neighbor.Lat, neighbor.Lon);
                })
                .First();

            ordered.Add(next);
            remaining.Remove(next);
            current = next;
        }

        return ordered;
    }

    private double ToRad(double degrees) => degrees * Math.PI / 180;
}
