using WebApi.Models;

namespace WebApi.Services;

internal class InMemoryBasketStore : IBasketStore
{
    private readonly Dictionary<int, int> _items = new();

    public void AddItem(int pizzaId, int quantity)
    {
        if (_items.ContainsKey(pizzaId))
        {
            _items[pizzaId] += quantity;
        }
        else
        {
            _items[pizzaId] = quantity;
        }
    }

    public bool UpdateQuantity(int pizzaId, int quantity)
    {
        if (!_items.ContainsKey(pizzaId))
        {
            return false;
        }

        if (quantity <= 0)
        {
            _items.Remove(pizzaId);
        }
        else
        {
            _items[pizzaId] = quantity;
        }

        return true;
    }

    public bool RemoveItem(int pizzaId) => _items.Remove(pizzaId);

    public Basket GetBasket() => new Basket(_items.Select(kvp => new BasketItem(kvp.Key, kvp.Value)).ToList());

    public void Clear() => _items.Clear();
}
