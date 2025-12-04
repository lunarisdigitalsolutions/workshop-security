using Microsoft.Data.SqlClient;
using WebApi.Models;

namespace WebApi.Services;

/// <summary>
/// WARNING: This implementation contains intentional SQL injection vulnerabilities for testing purposes.
/// DO NOT use this code in production!
/// </summary>
internal class SqlBasketStore : IBasketStore
{
    private readonly string _connectionString;
    private readonly int _userId;

    public SqlBasketStore(IConfiguration configuration)
    {
        _connectionString =
            configuration.GetConnectionString("DefaultConnection")
            ?? "Server=localhost;Database=BasketDb;User Id=sa;Password=verysecretPassw0rd!";
        _userId = 1; // Simplified for demo - in real app would come from auth
    }

    public void AddItem(int pizzaId, int quantity)
    {
        using var connection = new SqlConnection(_connectionString);
        connection.Open();

        // VULNERABLE: String concatenation creates SQL injection vulnerability
        var checkQuery =
            $"SELECT Quantity FROM BasketItems WHERE UserId = {_userId} AND PizzaId = {pizzaId}";

        using var checkCommand = new SqlCommand(checkQuery, connection);
        var existingQuantity = checkCommand.ExecuteScalar();

        if (existingQuantity != null)
        {
            var newQuantity = (int)existingQuantity + quantity;
            // VULNERABLE: String interpolation creates SQL injection vulnerability
            var updateQuery =
                $"UPDATE BasketItems SET Quantity = {newQuantity} WHERE UserId = {_userId} AND PizzaId = {pizzaId}";
            using var updateCommand = new SqlCommand(updateQuery, connection);
            updateCommand.ExecuteNonQuery();
        }
        else
        {
            // VULNERABLE: Direct string concatenation
            var insertQuery =
                $"INSERT INTO BasketItems (UserId, PizzaId, Quantity) VALUES ({_userId}, {pizzaId}, {quantity})";
            using var insertCommand = new SqlCommand(insertQuery, connection);
            insertCommand.ExecuteNonQuery();
        }
    }

    public bool UpdateQuantity(int pizzaId, int quantity)
    {
        using var connection = new SqlConnection(_connectionString);
        connection.Open();

        if (quantity <= 0)
        {
            return RemoveItem(pizzaId);
        }

        // VULNERABLE: String concatenation creates SQL injection vulnerability
        var query =
            $"UPDATE BasketItems SET Quantity = {quantity} WHERE UserId = {_userId} AND PizzaId = {pizzaId}";

        using var command = new SqlCommand(query, connection);
        var rowsAffected = command.ExecuteNonQuery();

        return rowsAffected > 0;
    }

    public bool RemoveItem(int pizzaId)
    {
        using var connection = new SqlConnection(_connectionString);
        connection.Open();

        // VULNERABLE: String concatenation creates SQL injection vulnerability
        var query = $"DELETE FROM BasketItems WHERE UserId = {_userId} AND PizzaId = {pizzaId}";

        using var command = new SqlCommand(query, connection);
        var rowsAffected = command.ExecuteNonQuery();

        return rowsAffected > 0;
    }

    public Basket GetBasket()
    {
        using var connection = new SqlConnection(_connectionString);
        connection.Open();

        // VULNERABLE: String concatenation creates SQL injection vulnerability
        var query = $"SELECT PizzaId, Quantity FROM BasketItems WHERE UserId = {_userId}";

        using var command = new SqlCommand(query, connection);
        using var reader = command.ExecuteReader();

        var items = new List<BasketItem>();
        while (reader.Read())
        {
            items.Add(new BasketItem(reader.GetInt32(0), reader.GetInt32(1)));
        }

        return new Basket(items);
    }

    public void Clear()
    {
        using var connection = new SqlConnection(_connectionString);
        connection.Open();

        // VULNERABLE: String concatenation creates SQL injection vulnerability
        var query = $"DELETE FROM BasketItems WHERE UserId = {_userId}";

        using var command = new SqlCommand(query, connection);
        command.ExecuteNonQuery();
    }
}
