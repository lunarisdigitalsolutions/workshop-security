using WebApi.Models;

namespace WebApi.Services;

internal interface IBasketStore
{
    void AddItem(int pizzaId, int quantity);
    bool UpdateQuantity(int pizzaId, int quantity);
    bool RemoveItem(int pizzaId);
    Basket GetBasket();
    void Clear();
}
