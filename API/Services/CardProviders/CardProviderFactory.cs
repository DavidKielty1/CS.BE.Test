using API.Services.CardProviders.Interfaces;

namespace API.Services.CardProviders;

public class CardProviderFactory : ICardProviderFactory
{
    private readonly IServiceProvider _serviceProvider;
    private readonly Dictionary<string, Type> _providerTypes;

    public CardProviderFactory(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
        _providerTypes = new Dictionary<string, Type>
        {
            { "CSCards", typeof(CSCardsProvider) },
            { "ScoredCards", typeof(ScoredCardsProvider) }
        };
    }

    public ICardProvider GetProvider(string providerName)
    {
        if (!_providerTypes.TryGetValue(providerName, out var providerType))
        {
            throw new ArgumentException($"Unknown provider: {providerName}");
        }

        return (ICardProvider)ActivatorUtilities.CreateInstance(_serviceProvider, providerType);
    }

    public IEnumerable<ICardProvider> GetAllProviders()
    {
        return _providerTypes.Values
            .Select(type => (ICardProvider)ActivatorUtilities.CreateInstance(_serviceProvider, type));
    }
}