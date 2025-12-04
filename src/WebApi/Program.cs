using WebApi.Models;
using WebApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
    });
});

builder.Services.AddSingleton<IBasketStore, InMemoryBasketStore>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseCors(c => c.AllowAnyHeader().AllowAnyMethod().WithOrigins("http://localhost:4200"));

var securityHeadersPolicies = new HeaderPolicyCollection()
    .AddDefaultSecurityHeaders()
    .AddContentSecurityPolicy(builder =>
    {
        builder.AddDefaultSrc().Self();
        builder.AddStyleSrc().Self().UnsafeInline();
        builder.AddFontSrc().Self();
        builder.AddImgSrc().Self().Data();
        builder.AddScriptSrc().Self().UnsafeInline();
    });
app.UseSecurityHeaders(securityHeadersPolicies);

// Pizza data
var pizzas = new List<Pizza>
{
    new Pizza(
        1,
        "Margherita",
        "Classic pizza with tomato sauce, mozzarella, and basil",
        ["Tomato Sauce", "Mozzarella", "Basil", "Olive Oil"]
    ),
    new Pizza(
        2,
        "Pepperoni",
        "Spicy pepperoni with mozzarella and tomato sauce",
        ["Tomato Sauce", "Mozzarella", "Pepperoni"]
    ),
    new Pizza(
        3,
        "Quattro Formaggi",
        "Four cheese pizza with mozzarella, gorgonzola, parmesan, and fontina",
        ["Mozzarella", "Gorgonzola", "Parmesan", "Fontina"]
    ),
    new Pizza(
        4,
        "Vegetariana",
        "Vegetarian pizza with grilled vegetables",
        ["Tomato Sauce", "Mozzarella", "Bell Peppers", "Zucchini", "Eggplant", "Mushrooms"]
    ),
    new Pizza(
        5,
        "Diavola",
        "Spicy salami pizza with hot peppers",
        ["Tomato Sauce", "Mozzarella", "Spicy Salami", "Hot Peppers"]
    ),
    new Pizza(6, "Prosciutto e Funghi", "Ham and mushroom pizza", ["Tomato Sauce", "Mozzarella", "Ham", "Mushrooms"]),
};

// Pizza endpoints
app.MapGet("/pizzas", () => Results.Ok(pizzas)).WithName("GetPizzas").WithOpenApi();

app.MapGet(
        "/pizzas/{id}",
        (int id) =>
        {
            var pizza = pizzas.FirstOrDefault(p => p.Id == id);
            return pizza is not null ? Results.Ok(pizza) : Results.NotFound();
        }
    )
    .WithName("GetPizzaById")
    .WithOpenApi();

// Basket endpoints
app.MapPost(
        "/basket/items",
        (IBasketStore store, AddBasketItemRequest request) =>
        {
            if (pizzas.All(p => p.Id != request.PizzaId))
            {
                return Results.NotFound("Pizza not found");
            }

            store.AddItem(request.PizzaId, request.Quantity);
            return Results.Ok(store.GetBasket());
        }
    )
    .WithName("AddToBasket")
    .WithOpenApi();

app.MapPut(
        "/basket/items/{pizzaId}",
        (IBasketStore store, int pizzaId, UpdateBasketItemRequest request) =>
        {
            if (!store.UpdateQuantity(pizzaId, request.Quantity))
            {
                return Results.NotFound("Pizza not in basket");
            }

            return Results.Ok(store.GetBasket());
        }
    )
    .WithName("UpdateBasketItem")
    .WithOpenApi();

app.MapDelete(
        "/basket/items/{pizzaId}",
        (IBasketStore store, int pizzaId) =>
        {
            if (!store.RemoveItem(pizzaId))
            {
                return Results.NotFound("Pizza not in basket");
            }

            return Results.Ok(store.GetBasket());
        }
    )
    .WithName("RemoveFromBasket")
    .WithOpenApi();

app.MapGet("/basket", (IBasketStore store) => Results.Ok(store.GetBasket())).WithName("GetBasket").WithOpenApi();

app.MapPost(
        "/basket/confirm",
        (IBasketStore store) =>
        {
            var basket = store.GetBasket();
            if (basket.Items.Count == 0)
            {
                return Results.BadRequest("Basket is empty");
            }

            var orderId = Guid.NewGuid();
            store.Clear();
            return Results.Ok(new { OrderId = orderId, Message = "Order confirmed successfully" });
        }
    )
    .WithName("ConfirmOrder")
    .WithOpenApi();

await app.RunAsync().ConfigureAwait(false);
