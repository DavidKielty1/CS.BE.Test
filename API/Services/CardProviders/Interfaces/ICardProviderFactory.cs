namespace API.Services.CardProviders.Interfaces;

public interface ICardProviderFactory
{
    ICardProvider GetProvider(string providerName);
    IEnumerable<ICardProvider> GetAllProviders();
}